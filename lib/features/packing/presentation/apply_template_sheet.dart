import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_template.dart';
import 'packing_providers.dart';

Future<void> showApplyTemplateSheet(
  BuildContext context, {
  required String tripId,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => _ApplyTemplateSheet(tripId: tripId),
  );
}

class _ApplyTemplateSheet extends ConsumerStatefulWidget {
  const _ApplyTemplateSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_ApplyTemplateSheet> createState() =>
      _ApplyTemplateSheetState();
}

class _ApplyTemplateSheetState extends ConsumerState<_ApplyTemplateSheet> {
  /// Applying has no undo, so a second tap while the first apply is still
  /// in flight would silently duplicate the whole template.
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncTemplates = ref.watch(packingTemplatesProvider);

    if (asyncTemplates.hasError) {
      return SafeArea(
        child: ErrorState(
          onRetry: () => ref.invalidate(packingTemplatesProvider),
        ),
      );
    }

    final templates = asyncTemplates.valueOrNull ?? const <PackingTemplate>[];

    if (asyncTemplates.hasValue && templates.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Text(l10n.packingApplyTemplateEmpty),
        ),
      );
    }

    if (!asyncTemplates.hasValue) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final template in templates)
            ListTile(
              title: Text(template.name),
              enabled: !_applying,
              onTap: _applying ? null : () => _apply(template),
            ),
        ],
      ),
    );
  }

  Future<void> _apply(PackingTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _applying = true);

    final repo = ref.read(packingRepositoryProvider);
    try {
      final itemCountBefore =
          (await repo.watchTripItems(widget.tripId).first).length;
      await repo.applyTemplate(
        tripId: widget.tripId,
        templateId: template.id,
      );
      final itemCountAfter =
          (await repo.watchTripItems(widget.tripId).first).length;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.packingApplyTemplateApplied(
              itemCountAfter - itemCountBefore,
              template.name,
            ),
          ),
        ),
      );
    } catch (_) {
      // Leave the sheet open and re-enable the tiles so the user can retry
      // rather than staring at a sheet that silently did nothing.
      if (mounted) setState(() => _applying = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.packingApplyTemplateFailed)),
      );
    }
  }
}
