import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/empty_state.dart';

void main() {
  Widget emptyState() => EmptyState(
        icon: Icons.folder_outlined,
        title: 'Nothing here yet',
        body: 'Add something to get started.',
        ctaLabel: 'Add',
        onCta: () {},
      );

  testWidgets(
      'does not overflow when squeezed into a shorter-than-natural parent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(height: 150, child: emptyState()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Content still exists in the tree — just scrollable now, not clipped.
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('renders normally (icon, title, body, CTA) in a roomy parent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: emptyState()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add something to get started.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
  });
}
