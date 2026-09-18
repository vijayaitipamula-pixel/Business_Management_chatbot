import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class AssistantRequestException implements Exception {
  const AssistantRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks only to CubeFore's backend. OpenAI credentials and model selection
/// belong on the server. [accessToken] must return a signed-in user's token.
class ChatbotAiService {
  ChatbotAiService({String? endpoint, this.accessToken, http.Client? client})
    : endpoint =
          endpoint ?? const String.fromEnvironment('CUBEFORE_AI_ENDPOINT'),
      _client = client ?? http.Client();

  final String endpoint;
  final Future<String?> Function()? accessToken;
  final http.Client _client;
  bool get isConfigured => endpoint.isNotEmpty;

  Stream<String> respond(
    List<ChatMessage> history,
    String businessContext,
  ) async* {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)))) {
      throw const AssistantRequestException(
        'The assistant connection is not configured correctly.',
      );
    }
    try {
      final token = await accessToken?.call().timeout(
        const Duration(seconds: 15),
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/x-ndjson'
        ..body = jsonEncode({
          'messages': history
              .skip(history.length > 24 ? history.length - 24 : 0)
              .map(
                (m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                },
              )
              .toList(),
          'businessContext': businessContext,
        });
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 70));
      if (response.statusCode != 200) {
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 10),
        );
        throw AssistantRequestException(switch (response.statusCode) {
          401 || 403 => 'Please sign in again to use the AI assistant.',
          429 => 'The assistant is busy. Please try again shortly.',
          _ => 'Could not reach the assistant. Please try again.',
        });
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/x-ndjson')) {
        await response.stream.listen((_) {}).cancel();
        throw const AssistantRequestException(
          'The assistant returned an unexpected response.',
        );
      }
      var completed = false;
      var receivedText = false;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 70))) {
        if (line.trim().isEmpty) continue;
        final event = jsonDecode(line) as Map<String, dynamic>;
        if (event['error'] != null) {
          throw const AssistantRequestException(
            'The response was interrupted. Please retry.',
          );
        }
        if (event['delta'] is String && (event['delta'] as String).isNotEmpty) {
          receivedText = true;
          yield event['delta'] as String;
        }
        if (event['done'] == true) {
          completed = true;
          break;
        }
      }
      if (!completed || !receivedText) {
        throw const AssistantRequestException(
          'The response was incomplete. Please retry.',
        );
      }
    } on AssistantRequestException {
      rethrow;
    } on TimeoutException {
      throw const AssistantRequestException(
        'The assistant took too long. Please retry.',
      );
    } catch (_) {
      throw const AssistantRequestException(
        'Connection lost. Check your connection and retry.',
      );
    }
  }

  void dispose() => _client.close();
}
