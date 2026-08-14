import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/glass_chrome.dart';

void main() {
  testWidgets('renders its child inside a blurred backdrop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlassChrome(child: Text('Places')),
        ),
      ),
    );

    expect(find.text('Places'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('surface is translucent, not solid — reads as glass',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlassChrome(child: SizedBox()),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color!.a, closeTo(0.55, 0.01));
  });

  testWidgets(
      'the shadow-bearing DecoratedBox wraps the BackdropFilter, not the '
      'other way round — otherwise ClipRRect clips the shadow away and it '
      'never renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlassChrome(child: SizedBox()),
        ),
      ),
    );

    // Find the DecoratedBox that actually carries a boxShadow...
    final shadowBox = tester.widget<DecoratedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).boxShadow != null &&
            (widget.decoration as BoxDecoration).boxShadow!.isNotEmpty,
      ),
    );
    expect(shadowBox.decoration is BoxDecoration, isTrue);

    // ...and confirm it's an ancestor of BackdropFilter, i.e. OUTSIDE the
    // ClipRRect that clips the blurred glass — the fix for the shadow
    // being invisible.
    final shadowBoxFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          (widget.decoration as BoxDecoration).boxShadow != null &&
          (widget.decoration as BoxDecoration).boxShadow!.isNotEmpty,
    );
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: shadowBoxFinder,
      ),
      findsOneWidget,
    );
  });
}
