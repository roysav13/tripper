import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/files/local_file_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/local_images.dart';
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

  /// Captured once — the stored path this screen opened with, if any.
  /// Compared against [_coverPhotoPath] at save time to know whether the
  /// old file needs deleting (replaced or cleared) or left alone
  /// (unchanged, or a brand-new trip that never had one).
  late final String? _originalCoverPhotoPath;
  String? _coverPhotoPath;
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
    _originalCoverPhotoPath = t?.coverPhotoPath;
    _coverPhotoPath = t?.coverPhotoPath;
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
          Text(l10n.tripFormCoverPhoto),
          const SizedBox(height: AppSpacing.sm),
          _CoverPhotoField(
            path: _coverPhotoPath,
            onPick: _pickCoverPhoto,
            onClear: _clearCoverPhoto,
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

  Future<void> _pickCoverPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.journalPhotoSourceCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.journalPhotoSourceGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final files = ref.read(coverPhotoFileServiceProvider);
    final String imported;
    try {
      imported = await files.import(picked.path);
    } on FileTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tripFormCoverPhotoTooLarge)),
        );
      }
      return;
    }
    // A pick from earlier this session that was never saved — replace it
    // rather than leaking it (the original stored photo, if any, is left
    // alone until save so cancelling the form doesn't destroy it).
    if (_coverPhotoPath != null && _coverPhotoPath != _originalCoverPhotoPath) {
      await _deleteCoverQuietly(_coverPhotoPath!);
    }
    if (!mounted) return;
    setState(() => _coverPhotoPath = imported);
  }

  void _clearCoverPhoto() {
    final path = _coverPhotoPath;
    if (path != null && path != _originalCoverPhotoPath) {
      // An unsaved fresh import — nothing else references it.
      unawaited(_deleteCoverQuietly(path));
    }
    setState(() => _coverPhotoPath = null);
  }

  /// Best-effort cleanup — a locked/undeletable file must never abort a
  /// save or become an unhandled async error. An orphaned file is a
  /// low-stakes, recoverable leak.
  Future<void> _deleteCoverQuietly(String path) async {
    try {
      await ref.read(coverPhotoFileServiceProvider).delete(path);
    } catch (_) {
      // Best-effort cleanup only.
    }
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

    if (_originalCoverPhotoPath != null &&
        _originalCoverPhotoPath != _coverPhotoPath) {
      // Replaced or cleared — the old file is no longer referenced. A
      // cleanup failure (e.g. a locked file) must never block the trip's
      // other changes from saving; an orphaned file is a low-stakes,
      // recoverable leak, a silently-discarded edit is not.
      await _deleteCoverQuietly(_originalCoverPhotoPath);
    }

    final repo = ref.read(tripRepositoryProvider);
    if (widget.initial == null) {
      await repo.createTrip(
        name: _name.text,
        destinations: _destinations,
        startDate: _start,
        endDate: _end,
        colorTag: widget.initial?.colorTag ?? 0,
        coverPhotoPath: _coverPhotoPath,
      );
    } else {
      await repo.updateTrip(
        widget.initial!.copyWith(
          name: _name.text,
          destinations: _destinations,
          startDate: () => _start,
          endDate: () => _end,
          coverPhotoPath: () => _coverPhotoPath,
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
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton(
      onPressed: onPick,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          value == null
              ? Text(label, style: TextStyle(color: colors.inkMuted))
              : MonoText(TripDateFormatter.single(value!, l10n)),
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

class _CoverPhotoField extends ConsumerWidget {
  const _CoverPhotoField({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  /// Always a cover-store key: a pick is imported before it lands here.
  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onPick,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShape.radius),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              path == null
                  ? _placeholder(colors)
                  : Image(
                      image: LocalFileImage(
                        path!,
                        ref.watch(coverPhotoFileServiceProvider),
                      ),
                      fit: BoxFit.cover,
                      // No trip/gradient context here (this is a raw file
                      // picker preview, not tied to a Trip) — fall back to
                      // the same "no photo picked yet" placeholder rather
                      // than inventing a new visual.
                      errorBuilder: (_, __, ___) => _placeholder(colors),
                    ),
              if (path != null)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: onClear,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.dark.paper.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.dark.inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: colors.hairline,
            width: AppShape.hairlineWidth,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: colors.inkMuted,
            size: 32,
          ),
        ),
      );
}
