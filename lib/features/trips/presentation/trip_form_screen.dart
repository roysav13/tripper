import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';
import '../domain/trip_validator.dart';
import 'trip_card.dart';
import 'trip_providers.dart';

/// Create (initial == null) or edit an existing trip.
/// Dates are optional: none = planned, start-only = open-ended (one-way).
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.initial});

  final Trip? initial;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _destinationInput;
  late List<String> _destinations;
  DateTime? _start;
  DateTime? _end;
  List<TripValidationError> _errors = const [];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _name = TextEditingController(text: t?.name ?? '');
    _destinationInput = TextEditingController();
    _destinations = [...?t?.destinations];
    _start = t?.startDate;
    _end = t?.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _destinationInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? l10n.tripFormTitleNew
              : l10n.tripFormTitleEdit,
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.tripFormName,
              errorText: _errors.contains(TripValidationError.nameRequired)
                  ? l10n.errNameRequired
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.tripFormDestinations),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _destinations.length; i++)
                InputChip(
                  label: Text(_destinations[i]),
                  onDeleted: () => setState(() => _destinations.removeAt(i)),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _destinationInput,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: l10n.tripFormAddDestinationHint,
                    errorText:
                        _errors.contains(TripValidationError.noDestination)
                            ? l10n.errNoDestination
                            : null,
                  ),
                  onSubmitted: (_) => _addDestination(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: colors.accent),
                tooltip: l10n.tripFormAddDestination,
                onPressed: _addDestination,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.tripFormDates),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tripFormDatesHint,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: l10n.tripFormStartDate,
                  value: _start,
                  onPick: () => _pickDate(isStart: true),
                  onClear: _start == null
                      ? null
                      : () => setState(() {
                            _start = null;
                            _end = null;
                          }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DateField(
                  label: l10n.tripFormEndDate,
                  value: _end,
                  onPick: () => _pickDate(isStart: false),
                  onClear:
                      _end == null ? null : () => setState(() => _end = null),
                ),
              ),
            ],
          ),
          if (_dateError(l10n) != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
              child: Text(
                _dateError(l10n)!,
                style: TextStyle(color: colors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  String? _dateError(AppLocalizations l10n) {
    if (_errors.contains(TripValidationError.endWithoutStart)) {
      return l10n.errEndWithoutStart;
    }
    if (_errors.contains(TripValidationError.datesInverted) ||
        _errors.contains(TripValidationError.tooLong)) {
      return l10n.errDatesRequired;
    }
    return null;
  }

  void _addDestination() {
    final value = _destinationInput.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _destinations.add(value);
      _destinationInput.clear();
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = ref.read(clockProvider)();
    final initial = (isStart ? _start : _end) ?? _start ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    // Unsubmitted text in the destination field counts — common flow is
    // typing the only destination and hitting save without "+".
    _addDestination();
    final errors = validateTrip(
      name: _name.text,
      destinations: _destinations,
      startDate: _start,
      endDate: _end,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final repo = ref.read(tripRepositoryProvider);
    if (widget.initial == null) {
      await repo.createTrip(
        name: _name.text,
        destinations: _destinations,
        startDate: _start,
        endDate: _end,
        colorTag: widget.initial?.colorTag ?? 0,
      );
    } else {
      await repo.updateTrip(
        widget.initial!.copyWith(
          name: _name.text,
          destinations: _destinations,
          startDate: () => _start,
          endDate: () => _end,
        ),
      );
    }
    if (mounted) context.pop();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onPick,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          value == null
              ? Text(label, style: TextStyle(color: colors.inkMuted))
              : MonoText(TripDateFormatter.single(value!)),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 16, color: colors.inkMuted),
            )
          else
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: colors.inkMuted,
            ),
        ],
      ),
    );
  }
}
