import 'package:flutter/material.dart';

import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';

IconData packingCategoryIcon(PackingCategory category) => switch (category) {
      PackingCategory.clothing => Icons.checkroom_outlined,
      PackingCategory.documents => Icons.description_outlined,
      PackingCategory.electronics => Icons.power_outlined,
      PackingCategory.toiletries => Icons.soap_outlined,
      PackingCategory.other => Icons.inventory_2_outlined,
    };

String packingCategoryLabel(AppLocalizations l10n, PackingCategory category) =>
    switch (category) {
      PackingCategory.clothing => l10n.packingCatClothing,
      PackingCategory.documents => l10n.packingCatDocuments,
      PackingCategory.electronics => l10n.packingCatElectronics,
      PackingCategory.toiletries => l10n.packingCatToiletries,
      PackingCategory.other => l10n.packingCatOther,
    };

String packingStatusLabel(AppLocalizations l10n, PackingItemStatus status) =>
    switch (status) {
      PackingItemStatus.toPack => l10n.packingStatusToPack,
      PackingItemStatus.packed => l10n.packingStatusPacked,
      PackingItemStatus.worn => l10n.packingStatusWorn,
      PackingItemStatus.inWash => l10n.packingStatusInWash,
      PackingItemStatus.clean => l10n.packingStatusClean,
    };

/// The clothing-only status readout — a small display-only chip (it carries
/// no `onTap` of its own), kept visually inside the same [PillChip] language
/// the rest of the app uses. It doesn't absorb taps, so tapping it hits the
/// enclosing row and opens the same 5-option status menu the rest of the
/// card does.
class PackingStatusChip extends StatelessWidget {
  const PackingStatusChip({super.key, required this.status});

  final PackingItemStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PillChip(
      label: packingStatusLabel(l10n, status),
      selected: status != PackingItemStatus.toPack,
    );
  }
}
