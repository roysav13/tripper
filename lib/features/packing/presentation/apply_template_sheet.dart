import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
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

class _ApplyTemplateSheet extends ConsumerWidget {
  const _ApplyTemplateSheet({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(packingTemplatesProvider).valueOrNull ?? const [];

    if (templates.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Text(l10n.packingApplyTemplateEmpty),
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
              onTap: () async {
                final repo = ref.read(packingRepositoryProvider);
                final itemCountBefore =
                    (await repo.watchTripItems(tripId).first).length;
                await repo.applyTemplate(
                  tripId: tripId,
                  templateId: template.id,
                );
                final itemCountAfter =
                    (await repo.watchTripItems(tripId).first).length;
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.packingApplyTemplateApplied(
                        itemCountAfter - itemCountBefore,
                        template.name,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
