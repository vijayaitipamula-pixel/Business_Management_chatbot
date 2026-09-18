import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubefore_chatbot_demo/main.dart';

void main() {
  testWidgets('Cubefore Assistant loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const CubeforeChatbotDemoApp());

    expect(find.text('Cubefore Assistant'), findsOneWidget);
    expect(find.text('Free chatbot demo'), findsNothing);
  });

  testWidgets('Last option is reachable on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CubeforeChatbotDemoApp());
    final reports = find.widgetWithText(ActionChip, 'Reports');
    expect(reports.hitTestable(), findsNothing);

    for (var i = 0; i < 30 && reports.hitTestable().evaluate().isEmpty; i++) {
      await tester.tap(find.byTooltip('Next options'));
      await tester.pumpAndSettle();
    }

    expect(reports.hitTestable(), findsOneWidget);
    await tester.tap(reports);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
