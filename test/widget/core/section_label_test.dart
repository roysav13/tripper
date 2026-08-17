import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/section_label.dart';

void main() {
  testWidgets('an explicit color overrides the computed accent/inkMuted default',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SectionLabel('Filters', color: Color(0xFF123456)),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('FILTERS'));
    expect(textWidget.style?.color, const Color(0xFF123456));
  });

  testWidgets('without an explicit color, falls back to inkMuted (or accent)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SectionLabel('Pinned'),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('PINNED'));
    expect(textWidget.style?.color, AppColors.light.inkMuted);
  });
}
