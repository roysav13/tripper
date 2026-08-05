import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_photo.dart';
import 'journal_location_picker.dart';
import 'journal_providers.dart';

/// Bottom sheet to add or edit a journal entry: summary, an editable log
/// time (defaults to now, never DateTime.now() directly — clockProvider),
/// photos, and an optional location.
Future<void> showJournalEntryFormSheet(
  BuildContext context, {
  required String tripId,
  JournalEntry? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _JournalEntryForm(tripId: tripId, existing: existing),
    ),
  );
}

class _JournalEntryForm extends ConsumerStatefulWidget {
  const _JournalEntryForm({required this.tripId, this.existing});

  final String tripId;
  final JournalEntry? existing;

  @override
  ConsumerState<_JournalEntryForm> createState() => _JournalEntryFormState();
}

class _JournalEntryFormState extends ConsumerState<_JournalEntryForm> {
  final _summary = TextEditingController();
  DateTime? _loggedAt;
  bool _summaryError = false;
  bool _saving = false;

  late List<JournalPhoto> _keptPhotos;
  final _newPhotoPaths = <String>[];
  final _removedPhotoIds = <String>[];

  double? _lat;
  double? _lng;
  String? _placeName;
  String? _placeId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _summary.text = existing?.summary ?? '';
    _loggedAt = existing?.loggedAt ?? ref.read(clockProvider)();
    _keptPhotos = List.of(existing?.photos ?? const []);
    _lat = existing?.lat;
    _lng = existing?.lng;
    _placeName = existing?.placeName;
    _placeId = existing?.placeId;
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final isEdit = widget.existing != null;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        SectionLabel(
          isEdit ? l10n.journalEntryFormEditTitle : l10n.journalEntryFormTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(AppShape.radius),
          onTap: _pickLoggedAt,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM').format(_loggedAt!),
                        style: AppTextStyles.title
                            .copyWith(color: colors.inkPrimary),
                      ),
                      const SizedBox(height: 2),
                      MonoText(
                        DateFormat('yyyy · HH:mm').format(_loggedAt!),
                        muted: true,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_calendar_outlined, color: colors.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _summary,
          maxLines: 6,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.body.copyWith(color: colors.inkPrimary),
          decoration: InputDecoration(
            hintText: l10n.journalFieldSummary,
            errorText: _summaryError ? l10n.errJournalSummaryRequired : null,
            filled: true,
            fillColor: colors.paper,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppShape.radius),
              borderSide: BorderSide(
                color: colors.hairline,
                width: AppShape.hairlineWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppShape.radius),
              borderSide: BorderSide(
                color: colors.hairline,
                width: AppShape.hairlineWidth,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppShape.radius),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.place_outlined, size: 16),
                label: Text(
                  _placeName ??
                      (_lat != null
                          ? '${_lat!.toStringAsFixed(3)}, '
                              '${_lng!.toStringAsFixed(3)}'
                          : l10n.journalAddLocation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _pickLocation,
              ),
            ),
            if (_lat != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.inkMuted),
                tooltip: l10n.journalClearLocation,
                onPressed: () => setState(() {
                  _lat = null;
                  _lng = null;
                  _placeName = null;
                  _placeId = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in _keptPhotos)
                _PhotoThumb(
                  filePath: photo.filePath,
                  colors: colors,
                  onRemove: () => setState(() {
                    _keptPhotos.remove(photo);
                    _removedPhotoIds.add(photo.id);
                  }),
                ),
              for (final path in _newPhotoPaths)
                _PhotoThumb(
                  filePath: path,
                  colors: colors,
                  onRemove: () => setState(() => _newPhotoPaths.remove(path)),
                ),
              _AddPhotoTile(
                colors: colors,
                label: l10n.journalAddPhoto,
                onTap: _addPhoto,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// A single combined date+time wheel (friendlier than two sequential
  /// Material dialogs), with "Now"/"Today"/"Yesterday" shortcuts above it.
  Future<void> _pickLoggedAt() async {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.read(clockProvider)();
    var temp = _loggedAt ?? now;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colors = sheetContext.colors;
            bool isSameDay(DateTime a, DateTime b) =>
                a.year == b.year && a.month == b.month && a.day == b.day;
            final yesterday = now.subtract(const Duration(days: 1));

            return SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.journalPickNow),
                          selected: temp == now,
                          onSelected: (_) => setSheetState(() => temp = now),
                        ),
                        ChoiceChip(
                          label: Text(l10n.journalPickToday),
                          selected: isSameDay(temp, now) && temp != now,
                          onSelected: (_) => setSheetState(() {
                            temp = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              temp.hour,
                              temp.minute,
                            );
                          }),
                        ),
                        ChoiceChip(
                          label: Text(l10n.journalPickYesterday),
                          selected: isSameDay(temp, yesterday),
                          onSelected: (_) => setSheetState(() {
                            temp = DateTime(
                              yesterday.year,
                              yesterday.month,
                              yesterday.day,
                              temp.hour,
                              temp.minute,
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 200,
                      child: CupertinoDatePicker(
                        // Re-keyed only on chip taps, so the wheel jumps to
                        // match — never on its own onDateTimeChanged, which
                        // would otherwise reset mid-scroll.
                        key: ValueKey(temp),
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: temp,
                        use24hFormat: true,
                        onDateTimeChanged: (v) => temp = v,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(temp),
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null && mounted) setState(() => _loggedAt = picked);
  }

  Future<void> _pickLocation() async {
    final pick = await JournalLocationPicker.open(
      context,
      tripId: widget.tripId,
      initialLat: _lat,
      initialLng: _lng,
      initialPlaceName: _placeName,
      initialPlaceId: _placeId,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _lat = pick.lat;
      _lng = pick.lng;
      _placeName = pick.placeName;
      _placeId = pick.placeId;
    });
  }

  Future<void> _addPhoto() async {
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
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() => _newPhotoPaths.add(picked.path));
  }

  Future<void> _save() async {
    if (_summary.text.trim().isEmpty) {
      setState(() => _summaryError = true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(journalRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.createEntry(
        tripId: widget.tripId,
        summary: _summary.text,
        loggedAt: _loggedAt,
        lat: _lat,
        lng: _lng,
        placeName: _placeName,
        placeId: _placeId,
        photoSourcePaths: _newPhotoPaths,
      );
    } else {
      await repo.updateEntry(
        existing.copyWith(
          summary: _summary.text,
          loggedAt: _loggedAt,
          lat: () => _lat,
          lng: () => _lng,
          placeName: () => _placeName,
          placeId: () => _placeId,
        ),
        newPhotoSourcePaths: _newPhotoPaths,
        removedPhotoIds: _removedPhotoIds,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.filePath,
    required this.colors,
    required this.onRemove,
  });

  final String filePath;
  final AppColors colors;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: colors.hairline, width: 0.5),
              ),
              child: Image.file(
                File(filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.paper,
                  child:
                      Icon(Icons.broken_image_outlined, color: colors.inkMuted),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Material(
              color: colors.surface,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 16,
                icon: Icon(Icons.close, color: colors.inkMuted),
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: colors.hairline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add_a_photo_outlined, color: colors.accent),
        ),
      ),
    );
  }
}
