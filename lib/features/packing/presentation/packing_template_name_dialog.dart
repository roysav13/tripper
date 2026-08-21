import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shared "type a template name" dialog — used for both creating a new
/// template and renaming an existing one. Mirrors
/// `lib/features/places/presentation/list_name_dialog.dart`'s shape.
Future<String?> promptTemplateName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => _TemplateNameDialog(
      controller: controller,
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.cancel,
      errorText: l10n.errTemplateNameRequired,
    ),
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({
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
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
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
          labelText: AppLocalizations.of(context)!.templateNameLabel,
          errorText: _showError ? widget.errorText : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
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
