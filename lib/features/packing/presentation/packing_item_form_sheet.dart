import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

/// Add (or, with [existingLabel]/[existingId], edit) a trip packing item.
/// Category is only asked when creating — editing changes the label only,
/// so an item never has to move between category sections this round.
Future<void> showPackingItemFormSheet(
  BuildContext context, {
  required String tripId,
  String? existingId,
  String? existingLabel,
  PackingCategory? existingCategory,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ItemForm(
        tripId: tripId,
        existingId: existingId,
        existingLabel: existingLabel,
        existingCategory: existingCategory,
      ),
    ),
  );
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    required this.tripId,
    this.existingId,
    this.existingLabel,
    this.existingCategory,
  });

  final String tripId;
  final String? existingId;
  final String? existingLabel;
  final PackingCategory? existingCategory;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  late final TextEditingController _label;
  late PackingCategory _category;
  bool _labelError = false;
  bool _saving = false;

  bool get _isEdit => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existingLabel ?? '');
    _category = widget.existingCategory ?? PackingCategory.clothing;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(
          _isEdit ? l10n.packingItemFormEditTitle : l10n.packingItemFormAddTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _label,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.packingItemFormLabel,
            errorText: _labelError ? l10n.errPackingLabelRequired : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_isEdit) ...[
          Text(l10n.packingItemFormCategory),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in PackingCategory.values)
                PillChip(
                  label: packingCategoryLabel(l10n, c),
                  icon: packingCategoryIcon(c),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    setState(() => _labelError = label.isEmpty);
    if (label.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(packingRepositoryProvider);
    final existingId = widget.existingId;
    if (existingId == null) {
      await repo.addTripItem(
        tripId: widget.tripId,
        category: _category,
        label: label,
      );
    } else {
      await repo.updateTripItemLabel(existingId, label);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
