import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// A [Text] whose direction is estimated from its own content rather than
/// inherited from the ambient [Directionality] — a Latin title stays LTR
/// (and truncates from its trailing edge) even inside an RTL app, and a
/// Hebrew title stays RTL even inside an LTR one. For user-entered names
/// and titles, which carry no reliable relationship to the app's language.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        textDirection: Bidi.detectRtlDirectionality(text)
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
}
