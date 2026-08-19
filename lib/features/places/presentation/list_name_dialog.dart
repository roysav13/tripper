import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shared "type a list name" dialog — used for both creating a new list and
/// renaming an existing one. Returns the trimmed name, or `null` if the
/// user cancelled without entering anything valid.
Future<String?> promptListName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => _ListNameDialog(
      controller: controller,
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.cancel,
      errorText: l10n.errListNameRequired,
    ),
  );
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({
    required this.controller,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.errorText,
  });

  final TextEditingController controller;
  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String errorText;

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          errorText: _showError ? widget.errorText : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  void _submit() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(name);
  }
}
