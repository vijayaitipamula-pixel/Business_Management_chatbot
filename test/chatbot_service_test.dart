import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cubefore_chatbot_demo/models/chat_message.dart';
import 'package:cubefore_chatbot_demo/services/chatbot_ai_service.dart';
import 'package:cubefore_chatbot_demo/services/chatbot_engine_service.dart';
import 'package:cubefore_chatbot_demo/services/chatbot_local_data_service.dart';

void main() {
  for (final type in ['Income', 'Expense', 'Purchase']) {
    test('$type flow saves once and can restore a deleted transaction', () {
      final data = ChatbotLocalDataService();
      final engine = ChatbotEngineService(data);
      engine.handleAction('add_${type.toLowerCase()}');
      engine.handleUserMessage('125');
      if (type == 'Purchase') engine.handleUserMessage('Local supplier');
      engine.handleAction('category:Other');
      engine.handleUserMessage('Custom category');
      engine.handleAction('payment:Cash');
      engine.handleAction('date:Today');
      expect(engine.currentStep, 'confirm');
      expect(engine.handleAction('save_transaction'), contains('saved!'));
      expect(data.savedDemoTransactions.length, 1);
      engine.handleAction('save_transaction');
      expect(data.savedDemoTransactions.length, 1);
      expect(data.deleteDemoTransaction(0), isTrue);
      expect(
        engine.handleUserMessage('Restore transaction 1'),
        contains('Restored'),
      );
      expect(data.savedDemoTransactions.single['amount'], 125);
    });
  }

  test('Complete voice transaction offers confirmation controls', () {
    final engine = ChatbotEngineService(ChatbotLocalDataService());
    engine.handleVoiceCommand('spent 100 tea cash today');
    expect(engine.currentStep, 'confirm');
    expect(
      engine.getCurrentOptions().map((o) => o.action),
      contains('save_transaction'),
    );
  });

  test(
    'AI proxy receives user auth and bounded conversation, streams Unicode',
    () async {
      final service = ChatbotAiService(
        endpoint: 'https://example.com/api/chat',
        accessToken: () async => 'user-session',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer user-session');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect((body['messages'] as List).length, 24);
          expect(body.containsKey('model'), isFalse);
          return http.Response(
            '${jsonEncode({'delta': 'Revenue ₹'})}\n${jsonEncode({'delta': '100'})}\n{"done":true}\n',
            200,
            headers: {'content-type': 'application/x-ndjson; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final history = List.generate(
        30,
        (i) => ChatMessage(text: 'Message $i', isUser: true),
      );
      expect(
        await service.respond(history, 'Sample data').join(),
        'Revenue ₹100',
      );
    },
  );

  for (final status in [401, 429, 500]) {
    test('AI handles HTTP $status without exposing server details', () async {
      final service = ChatbotAiService(
        endpoint: 'https://example.com/api/chat',
        client: MockClient(
          (_) async => http.Response('private backend details', status),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.respond([ChatMessage(text: 'Help', isUser: true)], '').toList(),
        throwsA(
          isA<AssistantRequestException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private')),
          ),
        ),
      );
    });
  }

  test('Truncated streams are failures, not completed responses', () async {
    final service = ChatbotAiService(
      endpoint: 'https://example.com/api/chat',
      client: MockClient(
        (_) async => http.Response(
          '{"delta":"Partial"}\n',
          200,
          headers: {'content-type': 'application/x-ndjson'},
        ),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.respond([ChatMessage(text: 'Help', isUser: true)], '').toList(),
      throwsA(isA<AssistantRequestException>()),
    );
  });
}
