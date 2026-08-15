# Tripper Redesign — Phase 2b: Vault Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the Vault feature's two document card widgets — `DocumentRowTile` and `PinnedDocumentCard` — per a fresh visual direction worked out directly with the user (not a literal reading of the original design spec's vault prose, which this plan supersedes for these two widgets).

**Architecture:** Two tasks, same file (`lib/features/vault/presentation/document_widgets.dart`), split because the two widgets are independently reviewable. `DocumentRowTile` moves from `PaperCard` (hairline border, flat) to a genuinely elevated `Material` card with an asymmetric shape and a leading-edge accent bar (coral normally, amber when expired) — no perforation, just a real shadow. `PinnedDocumentCard` moves from a bordered flat card to a soft gradient wash built from the surface tone, not a separate "gold"/loud gradient. Both keep their existing constructor signatures, so no call site outside this file changes.

**Tech Stack:** Flutter/Dart, existing `AppColors`/`AppShape` tokens (Phase 1), no new dependencies.

**Spec:** This plan's design was resolved through a bounded visual-brainstorming round with the user (not `docs/superpowers/specs/2026-08-14-tripper-redesign-design.md`'s original vault prose, §5, which called for "its own gradient card treatment (gate-line recognition)" — an idea the user explicitly wanted revisited with fresh eyes rather than reconciled literally). Phase 1's tokens (`docs/superpowers/plans/2026-08-14-tripper-redesign-phase1-foundation.md`) and Phase 2a's precedents (`docs/superpowers/plans/2026-08-15-tripper-redesign-phase2a-trips.md`) are the load-bearing prior art — this plan reuses their tokens and several of their exact idioms (on-scrim vs. theme-aware ink judgment calls, RTL-directional shapes).

## Global Constraints

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart`. Every color here comes from `context.colors` (theme-aware) — this reskin does NOT use the fixed `AppColors.dark.*` on-scrim convention Phase 2a used for trip covers, because these cards are never at full gradient/photo strength (see Task 2's design note on why theme-aware ink is the correct call here, not a shortcut).
- RTL-safe: the row tile's accent bar and the pinned card's gradient direction both use directional geometry (`BorderRadiusDirectional`, `AlignmentDirectional`) so they mirror correctly, not literal `left`/`right` or `topLeft`/`bottomRight`.
- Both widgets keep their exact existing public constructors (`DocumentRowTile({doc, warning, onTap})`, `PinnedDocumentCard({doc, warning, onTap})`) — every call site (`vault_screen.dart`'s pinned grid and category sections, and any trip-documents-tab usage) is unaffected by this plan.
- Tests land in the same commit as the feature (CLAUDE.md rule 5).

---

### Task 1: `DocumentRowTile` — elevated card with a leading accent edge

**Files:**
- Modify: `lib/features/vault/presentation/document_widgets.dart:94-148` (the `DocumentRowTile` class)
- Modify: `test/widget/vault/vault_screen_test.dart:19-28` (`_hasWarningBorder` helper) and its two call sites (lines 106, 123)
- Test: `test/widget/vault/document_widgets_test.dart` (new)

**Interfaces:**
- Produces: `DocumentRowTile`'s public API is unchanged (`{required Document doc, required bool warning, VoidCallback? onTap}`) — Task 2 and any existing caller need no changes.

- [x] **Step 1: Write the failing tests**

Create `test/widget/vault/document_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

final _today = DateTime(2026, 7, 19);

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

Document _doc({bool pinned = false, DateTime? expiry}) => Document(
      id: 'd1',
      title: 'Passport',
      category: DocumentCategory.passportId,
      createdAt: _today,
      isPinned: pinned,
      expiryDate: expiry,
    );

void main() {
  group('DocumentRowTile', () {
    testWidgets('renders as a real elevated Material card', (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final material = tester.widget<Material>(
        find.ancestor(
          of: find.text('Passport'),
          matching: find.byType(Material),
        ).first,
      );
      expect(material.elevation, greaterThan(0));
    });

    testWidgets('the leading edge is coral normally, amber when expired',
        (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();
      final normalEdges =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        normalEdges.any((b) => b.color == AppColors.dark.accent),
        isTrue,
      );

      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(), warning: true)),
      );
      await tester.pumpAndSettle();
      final warningEdges =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        warningEdges.any((b) => b.color == AppColors.dark.warning),
        isTrue,
      );
    });

    testWidgets('the accent edge sits on the leading side in RTL too',
        (tester) async {
      await tester.pumpWidget(
        _app(
          DocumentRowTile(doc: _doc(), warning: false),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();

      final edge = tester.getTopLeft(find.byType(ColoredBox).first);
      final text = tester.getTopLeft(find.text('Passport'));
      // RTL: the leading (start) edge is the right side of the screen —
      // the accent bar must sit to the right of the title, not the left.
      expect(edge.dx, greaterThan(text.dx));
    });

    testWidgets('tapping the tile fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          DocumentRowTile(
            doc: _doc(),
            warning: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Passport'));
      expect(tapped, isTrue);
    });

    testWidgets('pinned indicator still renders', (tester) async {
      await tester.pumpWidget(
        _app(DocumentRowTile(doc: _doc(pinned: true), warning: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    });
  });
}
```

- [x] **Step 2: Run the tests to confirm they fail**

Run: `flutter test test/widget/vault/document_widgets_test.dart`
Expected: FAIL — the current `DocumentRowTile` uses `PaperCard` (hairline border, no elevation, no `ColoredBox` edge).

- [x] **Step 3: Rewrite `DocumentRowTile`**

In `lib/features/vault/presentation/document_widgets.dart`, replace the `DocumentRowTile` class (lines 94-148):

```dart
/// One document = one card (matches the trips list), used in the vault
/// and in a trip's Documents tab. A real elevated Material card with a
/// leading accent edge — coral normally, amber when the document has
/// expired (replaces the old full-border warning treatment: only the
/// edge changes color now, not the whole card outline).
class DocumentRowTile extends StatelessWidget {
  const DocumentRowTile({
    super.key,
    required this.doc,
    required this.warning,
    this.onTap,
  });

  final Document doc;
  final bool warning;
  final VoidCallback? onTap;

  static const _shape = BorderRadiusDirectional.only(
    topStart: Radius.circular(4),
    bottomStart: Radius.circular(4),
    topEnd: Radius.circular(AppShape.radius),
    bottomEnd: Radius.circular(AppShape.radius),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final edgeColor = warning ? colors.warning : colors.accent;

    return Material(
      color: colors.surface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: _shape),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(color: edgeColor, child: const SizedBox(width: 5)),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(doc.category),
                      size: 20,
                      color: warning ? colors.warning : colors.inkSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoDirectionText(
                            doc.title,
                            style: AppTextStyles.body.copyWith(
                              color: colors.inkPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          MonoText(
                            documentMetaLine(l10n, doc),
                            color: warning ? colors.warning : null,
                          ),
                        ],
                      ),
                    ),
                    if (doc.isPinned)
                      Icon(
                        Icons.push_pin_outlined,
                        size: 16,
                        color: colors.accent,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Update the shared `_hasWarningBorder` test helper**

The old helper looked for a `PaperCard`-style bordered `Material`; the new design signals warning via the `ColoredBox` edge color instead, so it needs rewriting, not just a call-site tweak.

In `test/widget/vault/vault_screen_test.dart`, replace lines 19-28:

```dart
/// True if any document card in the tree is currently drawing its coral
/// leading edge in the warning (amber) color instead of the normal
/// accent color (M5, 2026-07-23: expired-only, not "expiring soon" too;
/// redesign, 2026-08-15: signaled by the edge color, not a card border).
bool _hasWarningEdge(WidgetTester tester) {
  final edges = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
  return edges.any((b) => b.color == AppColors.light.warning);
}
```

Then update both call sites in the same file: line 106 (`expect(_hasWarningBorder(tester), isFalse);` → `expect(_hasWarningEdge(tester), isFalse);`) and line 123 (`expect(_hasWarningBorder(tester), isTrue);` → `expect(_hasWarningEdge(tester), isTrue);`).

- [x] **Step 5: Run the tests again to confirm they pass**

Run: `flutter test test/widget/vault/document_widgets_test.dart test/widget/vault/vault_screen_test.dart`
Expected: PASS (all tests in both files, including the two updated warning-detection tests).

- [x] **Step 6: Run the full vault test folder**

Run: `flutter test test/widget/vault test/unit/vault`
Expected: PASS — confirms no other vault test (document form, actions sheet, show-code) depended on `DocumentRowTile`'s old `PaperCard`-based structure.

- [x] **Step 7: Commit**

```bash
git add lib/features/vault/presentation/document_widgets.dart test/widget/vault/vault_screen_test.dart test/widget/vault/document_widgets_test.dart
git commit -m "feat(vault): give DocumentRowTile a real elevation and accent edge"
```

---

### Task 2: `PinnedDocumentCard` — soft gradient wash

**Files:**
- Modify: `lib/features/vault/presentation/document_widgets.dart:150-195` (the `PinnedDocumentCard` class)
- Modify: `test/widget/vault/document_widgets_test.dart` (extend, from Task 1)
- Modify: `test/widget/accessibility_test.dart` (extend — see Step 5)

**Interfaces:**
- Consumes: `AppColors.surface`, `AppColors.heroGradientEnd` (both shipped in Phase 1) — no new tokens.
- Produces: `PinnedDocumentCard`'s public API is unchanged.

**Design note — why theme-aware ink, not the fixed on-scrim convention Phase 2a used for trip covers:** trip covers are full-strength photos or hero gradients, dark enough in both themes to need the fixed `AppColors.dark.inkPrimary` so text stays legible regardless of app theme. This card's gradient tops out at a 35%-blended wash of `heroGradientEnd` over the card's own `surface` color — in light mode that's a pale pink-ish tint on a near-white base, and fixed dark-mode ink (an off-white/cream tone) would be nearly invisible against it. Theme-aware `colors.inkPrimary` — already contrast-audited against `colors.surface` in both themes by Phase 1's WCAG work — is the correct choice here specifically because this gradient never gets dark/saturated enough to need the fixed convention.

- [x] **Step 1: Write the failing tests**

Append to `test/widget/vault/document_widgets_test.dart`, inside `main()`, after the `DocumentRowTile` group:

```dart
  group('PinnedDocumentCard', () {
    testWidgets('renders a two-stop gradient from surface toward '
        'heroGradientEnd, not a flat color', (tester) async {
      await tester.pumpWidget(
        _app(PinnedDocumentCard(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final ink = tester.widget<Ink>(find.byType(Ink));
      final decoration = ink.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, hasLength(2));
      expect(gradient.colors.first, AppColors.dark.surface);
      // The second stop is a blend, not the raw token — it must not equal
      // heroGradientEnd outright (that would be full-strength, the exact
      // "too strong" the user asked to soften), and must not equal the
      // first stop either (that would be no gradient at all).
      expect(gradient.colors[1], isNot(AppColors.dark.heroGradientEnd));
      expect(gradient.colors[1], isNot(gradient.colors[0]));
    });

    testWidgets('title and category icon use theme ink, not fixed on-scrim '
        'ink', (tester) async {
      await tester.pumpWidget(
        _app(PinnedDocumentCard(doc: _doc(), warning: false)),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<AutoDirectionText>(
        find.byType(AutoDirectionText),
      );
      expect(title.style?.color, AppColors.dark.inkPrimary);
    });

    testWidgets('tapping the card fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          PinnedDocumentCard(
            doc: _doc(),
            warning: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Passport'));
      expect(tapped, isTrue);
    });
  });
```

Add the import needed for `AutoDirectionText` at the top of the test file:
```dart
import 'package:tripper/core/widgets/auto_direction_text.dart';
```

- [x] **Step 2: Run the tests to confirm they fail**

Run: `flutter test test/widget/vault/document_widgets_test.dart`
Expected: FAIL — the current `PinnedDocumentCard` has no `Ink`/gradient at all (it's a bordered `PaperCard`).

- [x] **Step 3: Rewrite `PinnedDocumentCard`**

In `lib/features/vault/presentation/document_widgets.dart`, replace the `PinnedDocumentCard` class (lines 150-195, the end of the file):

```dart
/// Pinned quick-access card: a soft gradient wash built from the card's
/// own surface tone toward a muted `heroGradientEnd` — the same "your
/// most important documents get their own moment" idea trip covers use,
/// deliberately much softer (35% peak, not full strength) since this is
/// a document, not a photo.
class PinnedDocumentCard extends StatelessWidget {
  const PinnedDocumentCard({
    super.key,
    required this.doc,
    required this.warning,
    this.onTap,
  });

  final Document doc;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              colors.surface,
              Color.lerp(colors.surface, colors.heroGradientEnd, 0.35)!,
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(categoryIcon(doc.category), size: 18, color: colors.accent),
                const SizedBox(height: AppSpacing.sm),
                AutoDirectionText(
                  doc.title,
                  style: AppTextStyles.label.copyWith(color: colors.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                MonoText(
                  doc.expiryDate != null
                      ? _expiryText(l10n, doc.expiryDate!)
                      : categoryLabel(l10n, doc.category),
                  color: warning ? colors.warning : null,
                  muted: !warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Run the tests again to confirm they pass**

Run: `flutter test test/widget/vault/document_widgets_test.dart`
Expected: PASS (all tests, both groups).

- [x] **Step 5: Add dark-mode contrast coverage for the Vault screen**

`test/widget/accessibility_test.dart` already exercises the Vault tab in light mode (`'vault meets tap target and contrast guidelines'`). This is a new gradient/ink combination in dark mode too — read the file's existing `_populatedApp` helper and the vault test to see the current pattern, then add a dark-mode counterpart following the same structure used for the light-mode version (if `_populatedApp` doesn't yet take a theme-mode parameter, add one the same way Phase 1's fix round did for this exact file — check `AppTheme.dark()`/theme-mode-provider override patterns already in this file before adding a new one from scratch).

Run: `flutter test test/widget/accessibility_test.dart`
Expected: PASS, including the new dark-mode vault case.

- [x] **Step 6: Run the full vault test folder plus accessibility**

Run: `flutter test test/widget/vault test/unit/vault test/widget/accessibility_test.dart`
Expected: PASS.

- [x] **Step 7: Run the whole suite**

Run: `flutter test`
Expected: PASS — this is the last task in the plan.

- [x] **Step 8: Commit**

```bash
git add lib/features/vault/presentation/document_widgets.dart test/widget/vault/document_widgets_test.dart test/widget/accessibility_test.dart
git commit -m "feat(vault): give PinnedDocumentCard a soft gradient wash"
```
