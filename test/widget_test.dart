import 'package:fayko/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Arabic home feed with right-to-left direction', (
    tester,
  ) async {
    await tester.pumpWidget(const FaykoApp());

    expect(find.text('فايكو'), findsOneWidget);
    expect(find.text('أهلاً بك في فايكو 👋'), findsOneWidget);
    expect(find.text('ماكو منشورات لحد الآن'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.ancestor(
        of: find.byType(FaykoHomePage),
        matching: find.byType(Directionality),
      ).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('bottom navigation opens the reels section', (tester) async {
    await tester.pumpWidget(const FaykoApp());

    await tester.tap(find.text('ريلز'));
    await tester.pumpAndSettle();

    expect(find.text('فايكو ريلز'), findsOneWidget);
    expect(find.text('مقاطع قصيرة — قريباً'), findsOneWidget);
  });

  testWidgets('bottom navigation opens the chat section', (tester) async {
    await tester.pumpWidget(const FaykoApp());

    await tester.tap(find.text('الدردشة'));
    await tester.pumpAndSettle();

    expect(find.text('المحادثات'), findsOneWidget);
  });
}
