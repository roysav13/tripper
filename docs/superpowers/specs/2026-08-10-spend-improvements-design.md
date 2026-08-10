# Spend feature improvements

Status: approved, not yet implemented. First of five independent sub-projects
scoped out from a larger batch request (Spend, Place, Vault, Hebrew/RTL,
trip-subtitle — see conversation; the other four get their own specs).

## Problem

The Spend tab (`lib/features/expenses/presentation/trip_expenses_tab.dart`)
has four independent usability gaps:

1. "Add expense" is a plain `OutlinedButton` at the very bottom of the
   expense list — on a trip with more than a few expenses, adding a new one
   means scrolling all the way down every time.
2. Expenses render as one flat list, newest first, with no date structure —
   a trip with many expenses is a long undifferentiated scroll.
3. (Depends on #2) Once grouped, there's no way to collapse older groups out
   of the way — the grouping alone doesn't reduce scroll length, it just adds
   headers to it.
4. Deleting an expense (`ExpenseRowCard`'s `IconButton(Icons.close)`) fires
   immediately — `repo.deleteExpense()` then a "deleted" snackbar, no
   confirmation, no undo. A mis-tap silently loses data.

A fifth issue was surfaced during design: expense group totals need to
collapse mixed-currency trips into one figure, which only works if every
trip actually has a home currency to convert into — today `homeCurrency`
(`lib/core/settings/settings_service.dart`'s `HomeCurrencyController`) is
optional and empty by default ("conversion off").

## Design

### 1. Add-expense FAB

`TripExpensesTab`'s `build()` wraps its returned `ListView`/`EmptyState` in
its own nested `Scaffold` (`backgroundColor: Colors.transparent`, `body:
<existing content>`, `floatingActionButton: <new>`). A nested Scaffold
scopes the FAB to just this tab's subtree automatically — no need to track
which of the trip detail screen's four tabs is currently active from the
parent (`trip_detail_screen.dart` stays untouched).

The FAB only appears on the non-empty path. When the list is empty,
`EmptyState`'s existing CTA button already offers "Add an expense" front and
center — a floating button on top of that would be a second, redundant
affordance for the same action in the same view.

The current inline `OutlinedButton.icon` at the bottom of the list is
removed entirely (its job is now the FAB).

Both the FAB and the empty-state CTA route through the same new
`_addExpense` entry point (see "Mandatory home currency" below) instead of
calling `showExpenseFormSheet` directly.

### 2. Adaptive day/week/month grouping

A new pure function in `lib/features/expenses/domain/expense.dart` (next to
the existing `totalsByCurrency`/`categoryBreakdown`/`tripCurrency` free
functions, same module, no new file needed for the domain logic):

```dart
enum ExpenseGroupGranularity { day, week, month }

/// Which granularity to group at, based on how long the trip spans.
/// Starting thresholds — like every other tunable constant in this
/// codebase, meant for on-device tuning once it's visible on a real trip.
/// Uses trip.startDate/endDate when both are set (the trip's planned
/// span); falls back to the actual spread of expense dates (oldest to
/// newest) when either date is missing, so grouping still degrades
/// sensibly for trips created before start/end dates were required.
ExpenseGroupGranularity granularityFor(Trip trip, List<Expense> expenses);

class ExpenseGroup {
  final ExpenseGroupGranularity granularity;
  final DateTime periodStart;   // start of the day/week/month this group covers
  final List<Expense> expenses; // this group's expenses, already in the
                                 // same newest-first order the DAO provides
  final List<CurrencyAmount> perCurrencyTotals; // legacy/no-home-currency fallback
  final HomeTotal? homeTotal;   // this group's total in home currency, when available
  final int pendingConversionCount; // expenses in this group missing a conversion
}

/// Buckets [expenses] (already sorted newest-first) into ordered groups at
/// the granularity granularityFor(trip, expenses) picks. Pure — no
/// widget/DB dependency, same shape as groupEntriesByProximity in Journal.
List<ExpenseGroup> groupExpenses(
  Trip trip,
  List<Expense> expenses,
  String homeCurrency,
);
```

Thresholds: trip span ≤ 21 days → `day` (header e.g. "MON, MAR 3"); ≤ 90
days → `week` ("WEEK OF MAR 3"); longer → `month` ("MARCH 2026"). Headers
use the existing mono/uppercase `SectionLabel` styling already established
elsewhere in the app (Vault's category sections, Places' WANT/BEEN
sections) — new grouping headers, not a new visual language.

`TripExpensesTab` calls `groupExpenses` and renders one collapsible section
per group instead of one flat list of `ExpenseRowCard`s.

### 3. Collapsible groups, latest expanded by default

Each group renders as a header row (label, right-aligned total, chevron)
followed by its `ExpenseRowCard`s when expanded. `TripExpensesTab` becomes
(or delegates to) a `ConsumerStatefulWidget` holding `Set<DateTime>
_expandedGroups` (keyed by `periodStart`), seeded on first build to contain
only the first (newest) group's key. Tapping a header toggles membership in
that set. Purely in-memory UI state — resets on remount, same as every
other transient UI toggle in this app; no persistence needed.

### 4. Group totals in home currency, mandatory on first use

**Mandatory home currency.** `_addExpense(BuildContext, WidgetRef, {required
String tripId})` is the new single entry point both the FAB and the
empty-state CTA call:

```dart
Future<void> _addExpense(BuildContext context, WidgetRef ref, {required String tripId}) async {
  final home = ref.read(homeCurrencyProvider);
  if (home.isEmpty) {
    final chosen = await showCurrencyPicker(context, allowNone: false);
    if (chosen == null) return; // dismissed — cancel the whole add attempt
    await ref.read(homeCurrencyProvider.notifier).set(chosen);
  }
  if (!context.mounted) return;
  showExpenseFormSheet(context, tripId: tripId, /* ...existing params */);
}
```

`showCurrencyPicker(allowNone: false)` already exists exactly for "must
choose a real currency, no off switch" (`currency_picker.dart` — currently
used by Settings' own picker with `allowNone: true`; this is the first
`allowNone: false` call site). No new picker UI to build. Once set, this
never interrupts again — `homeCurrencyProvider` is a single app-wide
setting, not per-trip.

**Conversion timing needs no change.** `expenseConversionWiringProvider`
already listens to `allExpensesProvider` and re-attempts the backfill on
every list change, including immediately after an expense is added — so a
newly added expense already gets its stored home-currency conversion
attempted right away, not just at next app start. Making home currency
mandatory just guarantees there's always a real target to convert into.

**Group total display.** Each `ExpenseGroup.homeTotal` (sum of
`convertedAmountMinor` across the group's expenses, in `homeCurrency`) is
the primary figure shown on that group's header, styled like the existing
`ExpenseSummaryCard` mono total. Two fallbacks, both reusing patterns
already in `ExpenseSummaryCard`:

- **Pending conversions** (the brief async window right after adding, or a
  genuinely offline moment): show the home-currency total plus a small "N
  pending" note (`l10n.expensesConversionPending`, already exists) for the
  expenses in that group still missing a conversion.
- **No home currency at all** (legacy data from before this change, on a
  device that hasn't hit the new mandatory-gate flow yet — e.g. an existing
  trip viewed once right after updating, before "add expense" is tapped
  again): fall back to `perCurrencyTotals`, one line per currency, exactly
  today's `ExpenseSummaryCard` behavior. This path clears itself the first
  time the user adds a new expense on that device, same as the mandatory
  gate above.

The top-of-page `ExpenseSummaryCard` is unchanged by this spec — this only
changes the new per-group headers.

### 5. Manual delete confirmation

`ExpenseRowCard`'s delete `IconButton` still calls into
`TripExpensesTab._delete`, but that method now opens an `AlertDialog`
(Cancel / Delete) before calling `repo.deleteExpense` — same shape as
Place's existing delete confirmation
(`place_actions_sheet.dart`'s `_PlaceActions` delete flow: `deletePlaceTitle`
/ `deletePlaceBody` ARB keys, Cancel/Delete actions). New ARB keys
`deleteExpenseTitle` / `deleteExpenseBody` follow the same naming and
wording pattern. The existing "Expense deleted" snackbar still fires after
a confirmed delete — only the immediate, no-confirmation path is removed.

## Error handling

- Adding an expense while offline still succeeds (rule 4) — conversion
  simply stays pending until connectivity returns, same as today's
  established backfill behavior. Choosing a home currency requires no
  network at all (`kCurrencies` is a static bundled list).
- Dismissing the mandatory currency picker cancels the add attempt cleanly
  — no expense form opens, no partial state, no error shown.
- Every failure mode in the existing conversion pipeline
  (`ExpenseConversionService`, `ExchangeRateService`) is already
  best-effort/silent per rule 4 and is unchanged by this spec.

## Testing

- `granularityFor` and `groupExpenses`: pure, unit-tested directly — cover
  each threshold boundary (day/week/month), the trip-dates-missing fallback
  to expense-date spread, and per-group `homeTotal`/`perCurrencyTotals`/
  `pendingConversionCount` computation (mocked `Expense` fixtures with and
  without `convertedAmountMinor` set).
- Widget tests (repository boundary mocked, per rule 5): FAB present when
  expenses exist and absent on the empty state; tapping FAB/empty-CTA with
  no home currency set opens the currency picker before the expense form,
  and set with one skips straight to the form; tapping a collapsed group
  header expands it and shows its rows; the newest group starts expanded on
  first render; the delete `AlertDialog` appears on tapping the row's close
  icon and `deleteExpense` is only called after confirming, never after
  cancelling.
- No Drift schema change in this spec — no migration test needed.

## Out of scope this round

- Per-expense historical exchange rates (using the rate as of the
  expense's own `date` rather than "latest" at conversion time) — the
  `open.er-api.com` endpoint this app uses only exposes latest rates;
  historical lookup would be a separate, larger change to
  `ExchangeRateSource`.
- Changing the top-of-page `ExpenseSummaryCard`'s own multi-currency
  display — only the new per-group headers switch to home-currency totals.
- Persisting collapsed/expanded group state across app restarts.
- A settings-level way to make home currency optional again once set (the
  existing Settings screen's own picker, which already uses `allowNone:
  true`, is untouched — a user can still turn conversion back off there if
  they want; this spec only removes the "start with it off" default for
  new expense-adding, it doesn't remove the escape hatch entirely).
