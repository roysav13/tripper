import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripper/core/widgets/auto_direction_text.dart';

void main() {
  testWidgets('an English title renders LTR under an RTL ambient direction',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: AutoDirectionText('Trip to Paris'),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('Trip to Paris'));
    expect(textWidget.textDirection, TextDirection.ltr);
  });

  testWidgets('a Hebrew title renders RTL under an LTR ambient direction',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AutoDirectionText('טיול לפריז'),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('טיול לפריז'));
    expect(textWidget.textDirection, TextDirection.rtl);
  });

  testWidgets('style, maxLines and overflow pass through unchanged',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AutoDirectionText(
          'Some title',
          style: TextStyle(fontSize: 21),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('Some title'));
    expect(textWidget.style?.fontSize, 21);
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
