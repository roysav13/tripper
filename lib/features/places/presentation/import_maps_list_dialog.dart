import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sharing/maps_link.dart';
import '../../../l10n/app_localizations.dart';

/// Paste-a-link entry point for Google Maps sharing (mirrors the
/// share-intent flow — same `MapsLinkService.expand()` parse, just
/// triggered by pasting instead of Android's share sheet). Returns the
/// parsed share result, or null if the user cancelled.
Future<MapsShareResult?> promptMapsListUrl(
  BuildContext context,
  WidgetRef ref,
) {
  final controller = TextEditingController();
  return showDialog<MapsShareResult>(
    context: context,
    builder: (context) => _MapsUrlDialog(controller: controller, ref: ref),
  );
}

class _MapsUrlDialog extends StatefulWidget {
  const _MapsUrlDialog({required this.controller, required this.ref});

  final TextEditingController controller;
  final WidgetRef ref;

  @override
  State<_MapsUrlDialog> createState() => _MapsUrlDialogState();
}

class _MapsUrlDialogState extends State<_MapsUrlDialog> {
  bool _invalid = false;
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.importListDialogTitle),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.importListDialogHint,
          errorText: _invalid ? l10n.importListDialogInvalidLink : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _checking ? null : _submit,
          child: Text(l10n.importListDialogImport),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _checking = true;
      _invalid = false;
    });
    final result = await widget.ref.read(mapsLinkServiceProvider).expand(text);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _checking = false;
        _invalid = true;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }
}
