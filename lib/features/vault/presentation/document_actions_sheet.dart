import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/security/vault_lock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_providers.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';
import 'document_providers.dart';
import 'document_widgets.dart';
import 'show_code_screen.dart';

/// Tap a document row -> actions: open, pin, link to trips, delete.
/// Gated by the vault lock — documents opened from a trip's tab included.
Future<void> showDocumentActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Document doc,
) async {
  final l10n = AppLocalizations.of(context)!;
  final unlocked = await ref
      .read(vaultLockProvider.notifier)
      .ensureUnlocked(l10n.unlockReason);
  if (!unlocked || !context.mounted) return;
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (context) => _DocumentActions(doc: doc),
  );
}

class _DocumentActions extends ConsumerWidget {
  const _DocumentActions({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final repo = ref.read(documentRepositoryProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(categoryIcon(doc.category), color: colors.accent),
              title: Text(doc.title),
              subtitle: Text(documentMetaLine(l10n, doc)),
            ),
            const Divider(),
            if (ShowCodeScreen.canShow(doc))
              ListTile(
                leading: const Icon(Icons.qr_code_2_outlined),
                title: Text(l10n.showCodeAction),
                onTap: () {
                  Navigator.of(context).pop();
                  ShowCodeScreen.open(context, doc);
                },
              ),
            if (doc.hasFile)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.docActionOpen),
                onTap: () async {
                  Navigator.of(context).pop();
                  await OpenFilex.open(doc.filePath!);
                },
              ),
            ListTile(
              leading: Icon(
                doc.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title:
                  Text(doc.isPinned ? l10n.docActionUnpin : l10n.docActionPin),
              onTap: () async {
                // Same capture-before-pop pattern as the link tile below —
                // narrower window here (no intervening dialog), but the
                // same bug class if the write is ever slow.
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                try {
                  await repo.setPinned(doc.id, pinned: !doc.isPinned);
                } on PinLimitReachedException {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.pinLimitReached)),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.luggage_outlined),
              title: Text(l10n.docActionLink),
              onTap: () async {
                // Resolve everything from `ref` *before* popping — the pop
                // disposes this widget (and its `ref`) well before the user
                // finishes picking trips and taps Save, and `ref` throws if
                // read afterward. `repo` (like the pin/delete tiles above)
                // and `trips` are plain values with no widget lifecycle, so
                // they're safe to carry across the pop + the dialog's await.
                //
                // `.future` (not `.valueOrNull`) matters here too: nothing
                // else on the Vault tab watches tripListProvider, so on a
                // cold Vault-tab-first open its first value may not have
                // arrived yet. `.valueOrNull` would silently show "no trips"
                // in that race; `.future` waits for the real answer.
                List<Trip> trips;
                try {
                  trips = await ref.read(tripListProvider.future);
                } catch (_) {
                  trips = const [];
                }
                if (!context.mounted) return;
                // Same trap as `ref`, one level down: ScaffoldMessenger.of
                // (context) is a fresh ancestor *lookup*, so calling it
                // later — after the dialog closes — would resolve against
                // the sheet's already-disposed context again. Capturing the
                // resolved State here (it belongs to the persistent Vault/
                // trip screen underneath, not to this sheet) sidesteps that
                // entirely; the pop below doesn't invalidate it.
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                await _showLinkDialog(context, repo, trips, messenger, doc);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text(
                l10n.menuDelete,
                style: TextStyle(color: colors.error),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.deleteDocTitle),
                    content: Text(l10n.deleteDocBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.menuDelete),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) await repo.deleteDocument(doc.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkDialog(
    BuildContext context,
    DocumentRepository repo,
    List<Trip> trips,
    ScaffoldMessengerState messenger,
    Document doc,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = {...doc.tripIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.docActionLink),
          content: SizedBox(
            width: double.maxFinite,
            child: trips.isEmpty
                ? Text(l10n.noTripsToLink)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final trip in trips)
                        CheckboxListTile(
                          title: Text(trip.name),
                          value: selected.contains(trip.id),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              selected.add(trip.id);
                            } else {
                              selected.remove(trip.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await repo.setLinks(doc.id, result.toList());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.docLinksUpdated)),
      );
    } catch (e, st) {
      // setLinks was previously fire-and-forget here — any failure (FK
      // violation, closed DB, etc.) surfaced as nothing happening at all
      // from the user's perspective. Make failures visible instead.
      debugPrint('setLinks($doc.id, $result) failed: $e\n$st');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.docLinksUpdateFailed)),
      );
    }
  }
}
