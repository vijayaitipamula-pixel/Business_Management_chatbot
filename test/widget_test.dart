import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubefore_chatbot_demo/main.dart';
import 'package:cubefore_chatbot_demo/models/chat_message.dart';
import 'package:cubefore_chatbot_demo/screens/cubefore_assistant_screen.dart';
import 'package:cubefore_chatbot_demo/services/chatbot_ai_service.dart';
import 'package:cubefore_chatbot_demo/widgets/chat_message_card.dart';

Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(seconds: 1));
}

class ControlledAi extends ChatbotAiService {
  ControlledAi() : super(endpoint: 'https://example.com/api/chat');
  final streams = <StreamController<String>>[];
  final histories = <List<ChatMessage>>[];
  @override
  Stream<String> respond(List<ChatMessage> history, String businessContext) {
    histories.add(List.of(history));
    final stream = StreamController<String>();
    streams.add(stream);
    return stream.stream;
  }
}

void main() {
  testWidgets('Welcome retains greeting and removes demo subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(const CubeforeChatbotDemoApp());
    await advance(tester);
    expect(find.text('CubeFore AI'), findsOneWidget);
    expect(find.text('Hi! Let’s manage your business.'), findsOneWidget);
    expect(find.text('Free chatbot demo'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Send message',
            ),
          )
          .onPressed,
      isNull,
    );
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
      await advance(tester);
    }
    expect(reports.hitTestable(), findsOneWidget);
    await tester.tap(reports);
    await advance(tester);
    expect(
      tester
          .widgetList<ChatMessageCard>(find.byType(ChatMessageCard))
          .any((card) => card.message.text.contains('Open Reports')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Summary uses service data and keeps composer usable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(const CubeforeChatbotDemoApp());
      await tester.enterText(find.byType(TextField), 'Today summary');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await advance(tester);
      expect(find.byType(BusinessSummaryCard), findsOneWidget);
      expect(find.text('Sample data • this session only'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await advance(tester);
      await tester.enterText(
        find.byType(TextField),
        'A multiline\nbusiness question',
      );
      await advance(tester);
      expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AI streams, locks submissions, retries, and replaces regenerated response',
    (tester) async {
      final ai = ControlledAi();
      addTearDown(ai.dispose);
      await tester.pumpWidget(
        MaterialApp(home: CubeforeAssistantScreen(aiService: ai)),
      );
      await tester.enterText(
        find.byType(TextField),
        'How can I improve my business?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await advance(tester);
      expect(find.text('Thinking…'), findsWidgets);
      expect(ai.histories.length, 1);
      await tester.enterText(find.byType(TextField), 'Another question');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNull,
      );
      ai.streams[0].add('First part');
      await advance(tester);
      expect(find.text('First part'), findsOneWidget);
      ai.streams[0].addError(
        const AssistantRequestException('Connection lost'),
      );
      await advance(tester);
      expect(find.text('Retry response'), findsOneWidget);
      await tester.tap(find.text('Retry response'));
      await advance(tester);
      expect(ai.histories.length, 2);
      expect(ai.histories[1].length, ai.histories[0].length);
      ai.streams[1].add('A complete answer.');
      unawaited(ai.streams[1].close());
      await advance(tester);
      expect(find.byTooltip('Regenerate response'), findsOneWidget);
      await tester.tap(find.byTooltip('Regenerate response'));
      await advance(tester);
      ai.streams[2].add('An improved answer.');
      unawaited(ai.streams[2].close());
      await advance(tester);
      final cards = tester
          .widgetList<ChatMessageCard>(find.byType(ChatMessageCard))
          .toList();
      expect(cards.where((c) => c.message.isAi).length, 1);
      expect(cards.last.message.text, 'An improved answer.');
      expect(ai.histories[2].last.isUser, isTrue);
      expect(tester.takeException(), isNull);
      unawaited(ai.streams[0].close());
    },
  );

  testWidgets('Rich responses fit narrow dark screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageCard(
                message: ChatMessage(
                  isUser: false,
                  isAi: true,
                  text:
                      '# Report\n**Summary**\n\n- One item\n\n| Category | Amount | Notes |\n|---|---|---|\n| Office | 200 | Details |\n\n```dart\nfinal veryLongLine = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz";\n```\n[Link](https://example.com)',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await advance(tester);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Copy response'), findsNothing);
  });
}
