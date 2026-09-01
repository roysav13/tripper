import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_template.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

/// Adds or edits a packing item, on either a trip or a template — exactly
/// one of [tripId]/[templateId] must be non-null.
///
/// For a **trip** item, [existingId] + [existingLabel] are enough to edit
/// (label-only; category can't change after creation — see the class doc
/// below). For a **template** item, pass [existingTemplateItem] instead:
/// its `sortOrder` must round-trip through the edit because
/// [PackingRepository.updateTemplateItem] writes it straight through
/// rather than re-fetching it.
Future<void> showPackingItemFormSheet(
  BuildContext context, {
  String? tripId,
  String? templateId,
  String? existingId,
  String? existingLabel,
  PackingCategory? existingCategory,
  PackingTemplateItem? existingTemplateItem,
}) {
  assert((tripId == null) != (templateId == null));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ItemForm(
        tripId: tripId,
        templateId: templateId,
        existingId: existingId,
        existingLabel: existingLabel ?? existingTemplateItem?.label,
        existingCategory: existingCategory ?? existingTemplateItem?.category,
        existingTemplateItem: existingTemplateItem,
      ),
    ),
  );
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    this.tripId,
    this.templateId,
    this.existingId,
    this.existingLabel,
    this.existingCategory,
    this.existingTemplateItem,
  });

  final String? tripId;
  final String? templateId;
  final String? existingId;
  final String? existingLabel;
  final PackingCategory? existingCategory;
  final PackingTemplateItem? existingTemplateItem;

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
          _isEdit
              ? l10n.packingItemFormEditTitle
              : l10n.packingItemFormAddTitle,
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
    final tripId = widget.tripId;
    final templateId = widget.templateId;
    final existingTemplateItem = widget.existingTemplateItem;

    if (existingId != null && tripId != null) {
      await repo.updateTripItemLabel(existingId, label);
    } else if (existingTemplateItem != null) {
      await repo
          .updateTemplateItem(existingTemplateItem.copyWith(label: label));
    } else if (tripId != null) {
      await repo.addTripItem(tripId: tripId, category: _category, label: label);
    } else {
      await repo.addTemplateItem(
        templateId: templateId!,
        category: _category,
        label: label,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}
