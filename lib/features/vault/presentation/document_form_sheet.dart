import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database_provider.dart';
import '../../../core/platform/scratch_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/document_ocr_service.dart';
import '../domain/checkin_notifications.dart';
import '../domain/document.dart';
import '../domain/mrz_parser.dart';
import '../domain/travel_doc_parser.dart';
import 'document_providers.dart';
import 'document_widgets.dart';

/// Bottom sheet to add a document: pick a file or enter a manual record.
/// [tripId] pre-links the new document to that trip.
/// [initialFilePath] prefills a file arriving via the Android share target.
Future<void> showDocumentFormSheet(
  BuildContext context, {
  String? tripId,
  String? initialFilePath,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _DocumentForm(tripId: tripId, initialFilePath: initialFilePath),
    ),
  );
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({this.tripId, this.initialFilePath});

  final String? tripId;
  final String? initialFilePath;

  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm> {
  final _title = TextEditingController();
  final _detailA = TextEditingController();
  final _detailB = TextEditingController();
  DocumentCategory _category = DocumentCategory.other;
  DateTime? _expiry;
  DateTime? _departureTime;
  /// Handle for the attached file: a path on Android, a `blob:` URL in
  /// the browser. Only ever handed to code that knows how to read one.
  String? _pickedPath;

  /// The file's real name. Tracked separately because a `blob:` URL has
  /// neither a basename to show nor an extension to derive the MIME type
  /// from.
  String? _pickedName;
  bool _isGlobal = false;
  bool _titleError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialFilePath;
    if (shared != null) {
      _pickedPath = shared;
      _pickedName = p.basename(shared);
      _title.text = p.basenameWithoutExtension(shared);
      // OCR prefill for shared-in photos too — originally only the
      // "Attach file" path ran it, so sharing a passport photo into the
      // app silently skipped prefill (found on-device 2026-07-23).
      // Post-frame: prefill shows a snackbar, which needs a built context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryOcrPrefill(shared, fileName: p.basename(shared));
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _detailA.dispose();
    _detailB.dispose();
    super.dispose();
  }

  /// (label keys, detail map keys) per category — mirrors SPEC card anatomy.
  (String?, String?) _detailKeys() => switch (_category) {
        DocumentCategory.flight => ('flightNumber', 'confirmationCode'),
        DocumentCategory.stay => ('bookingRef', null),
        DocumentCategory.transport => ('confirmationCode', null),
        DocumentCategory.passportId => ('number', null),
        _ => (null, null),
      };

  String _detailLabel(AppLocalizations l10n, String key) => switch (key) {
        'flightNumber' => l10n.fieldFlightNumber,
        'confirmationCode' => l10n.fieldConfirmationCode,
        'bookingRef' => l10n.fieldBookingRef,
        'number' => l10n.fieldDocumentNumber,
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final (keyA, keyB) = _detailKeys();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Text(l10n.docFormTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in DocumentCategory.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    avatar: Icon(categoryIcon(c), size: 16),
                    label: Text(categoryLabel(l10n, c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.docFormName,
            errorText: _titleError ? l10n.errNameRequired : null,
          ),
        ),
        if (keyA != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _detailA,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: _detailLabel(l10n, keyA)),
          ),
        ],
        if (keyB != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _detailB,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: _detailLabel(l10n, keyB)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(
                  _pickedName ?? l10n.docFormAttachFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _pickFile,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _expiry == null
                      ? l10n.docFormExpiry
                      : DateFormat('dd MMM yyyy', l10n.localeName)
                          .format(_expiry!),
                ),
                onPressed: _pickExpiry,
              ),
            ),
          ],
        ),
        if (_category == DocumentCategory.flight) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.flight_takeoff_outlined, size: 16),
            label: Text(
              _departureTime == null
                  ? l10n.docFormDepartureTime
                  : DateFormat('dd MMM yyyy, HH:mm', l10n.localeName)
                      .format(_departureTime!),
            ),
            onPressed: _pickDepartureTime,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.docFormDepartureTimeHint,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.docFormGlobal),
          subtitle: Text(
            l10n.docFormGlobalHint,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
          value: _isGlobal,
          activeTrackColor: colors.accent,
          onChanged: (v) => setState(() => _isGlobal = v),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'html', 'htm'],
      // Browsers never expose a filesystem path, so ask for the bytes
      // there and park them in scratch storage to get a readable handle.
      withData: kIsWeb,
    );
    final picked = result?.files.singleOrNull;
    if (picked == null) return;
    final name = picked.name;

    var handle = picked.path;
    if (handle == null) {
      final bytes = picked.bytes;
      if (bytes == null) return;
      handle = await writeScratchFile(
        bytes,
        extension: p.extension(name),
        prefix: 'tripper_pick_',
      );
      if (handle == null) return;
    }

    setState(() {
      _pickedPath = handle;
      _pickedName = name;
      if (_title.text.trim().isEmpty) {
        _title.text = p.basenameWithoutExtension(name);
      }
    });
    await _tryOcrPrefill(handle, fileName: name);
  }

  /// M5.4: passport-MRZ OCR prefill. The what-to-fill rules live in
  /// `computeMrzPrefill` (pure, unit-tested — never clobbers typed
  /// input); this just runs OCR and applies the result. Works for photos
  /// and PDFs (first pages rasterized via `DocumentTextExtractor`). Any
  /// OCR failure or non-passport file silently prefills nothing
  /// (enhancement, not a gate).
  Future<void> _tryOcrPrefill(String handle, {String? fileName}) async {
    final path = fileName ?? handle;
    final text = await ref
        .read(documentTextExtractorProvider)
        .extract(handle, fileName: fileName);
    if (text.isEmpty) {
      _ocrLog('no text extracted (unsupported type, plugin failure, or '
          'blank/unreadable file)');
      return;
    }
    if (!mounted) return;
    final mrz = parseMrz(text);
    _ocrLog('recognized ${text.length} chars, '
        '${text.split('\n').length} lines — '
        'MRZ ${mrz == null ? 'not found' : 'found'}');

    if (mrz != null) {
      final prefill = computeMrzPrefill(
        mrz: mrz,
        currentCategory: _category,
        currentTitle: _title.text,
        autoTitleFromFile: p.basenameWithoutExtension(path),
        currentExpiry: _expiry,
        currentNumber: _detailA.text,
      );
      if (prefill.isEmpty) return;
      setState(() {
        if (prefill.category != null) _category = prefill.category!;
        if (prefill.title != null) _title.text = prefill.title!;
        if (prefill.expiry != null) _expiry = prefill.expiry;
        if (prefill.number != null) _detailA.text = prefill.number!;
      });
      _showPrefilledSnack();
      return;
    }

    // No MRZ — freeform extraction for flights/bookings/visas (M5.4
    // extension): flight number, confirmation code, departure, expiry.
    final l10n = AppLocalizations.of(context)!;
    final fields = parseTravelDoc(text, now: ref.read(clockProvider)());
    _ocrLog('travel-doc fields: '
        'flight=${fields.flightNumber != null}, '
        'code=${fields.confirmationCode != null}, '
        'departure=${fields.departureTime != null}, '
        'expiry=${fields.expiryDate != null}');
    // When something didn't extract, dump the keyword-adjacent lines so
    // the layout can be diagnosed instead of guessed at. Debug builds
    // only — this is real document content.
    if (kDebugMode &&
        (fields.confirmationCode == null ||
            fields.departureTime == null ||
            fields.flightNumber == null)) {
      for (final line in travelDocDebugLines(text)) {
        _ocrLog('  | $line');
      }
    }
    if (fields.isEmpty) return;
    final prefill = computeTravelPrefill(
      fields: fields,
      currentCategory: _category,
      currentTitle: _title.text,
      autoTitleFromFile: p.basenameWithoutExtension(path),
      currentExpiry: _expiry,
      currentDeparture: _departureTime,
      currentDetailA: _detailA.text,
      currentDetailB: _detailB.text,
      l10n: l10n,
    );
    if (prefill.isEmpty) return;
    setState(() {
      if (prefill.category != null) _category = prefill.category!;
      if (prefill.title != null) _title.text = prefill.title!;
      if (prefill.expiry != null) _expiry = prefill.expiry;
      if (prefill.departureTime != null) {
        _departureTime = prefill.departureTime;
      }
      if (prefill.detailA != null) _detailA.text = prefill.detailA!;
      if (prefill.detailB != null) _detailB.text = prefill.detailB!;
    });
    _showPrefilledSnack();
  }

  void _showPrefilledSnack() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.docOcrPrefilled)));
  }

  /// Debug-only OCR diagnostics — lengths and stage reached, never the
  /// recognized text itself (it's a passport).
  void _ocrLog(String message) {
    if (kDebugMode) debugPrint('[ocr] $message');
  }

  Future<void> _pickExpiry() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  /// Date then time, combined into one DateTime — the check-in reminder
  /// (M5.3) needs the actual departure instant, not just a calendar day.
  Future<void> _pickDepartureTime() async {
    final now = ref.read(clockProvider)();
    final initial = _departureTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _departureTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() => _saving = true);
    final (keyA, keyB) = _detailKeys();
    final details = <String, String>{
      if (keyA != null && _detailA.text.trim().isNotEmpty)
        keyA: _detailA.text.trim(),
      if (keyB != null && _detailB.text.trim().isNotEmpty)
        keyB: _detailB.text.trim(),
      if (_category == DocumentCategory.flight && _departureTime != null)
        kDepartureTimeDetailKey: _departureTime!.toIso8601String(),
    };
    final ext = _pickedName == null
        ? null
        : p.extension(_pickedName!).replaceFirst('.', '').toLowerCase();
    await ref.read(documentRepositoryProvider).createDocument(
      title: _title.text,
      category: _category,
      sourceFilePath: _pickedPath,
      mimeType: switch (ext) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'html' || 'htm' => 'text/html',
        _ => null,
      },
      expiryDate: _expiry,
      isGlobal: _isGlobal,
      details: details,
      tripIds: [if (widget.tripId != null) widget.tripId!],
    );
    if (mounted) Navigator.of(context).pop();
  }
}
