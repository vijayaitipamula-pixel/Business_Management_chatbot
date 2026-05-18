import 'package:flutter_test/flutter_test.dart';
import 'package:cubefore_chatbot_demo/main.dart';

void main() {
  testWidgets('Cubefore Assistant loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const CubeforeChatbotDemoApp());

    expect(find.text('Cubefore Assistant'), findsOneWidget);
    expect(find.text('Free chatbot demo'), findsOneWidget);
  });
}