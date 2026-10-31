import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:souq_akimi/core/ai_config.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/souq_exception.dart';
import 'package:souq_akimi/data/ai_assistant.dart';

http.Response answer(Object? content, {String finish = 'stop'}) =>
    http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
            'finish_reason': finish,
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  test(
    'description uses a complete-answer model and includes condition',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], AiConfig.groqModel);
        expect(body['model'], 'qwen/qwen3.8-27b');
        expect(body['max_completion_tokens'], greaterThanOrEqualTo(512));
        expect(body['messages'][1]['content'], contains('Condition: Used'));
        expect(body['messages'][1]['content'], contains('Language: English'));
        expect(request.headers['Authorization'], 'Bearer test-key');
        return answer('A used laptop in good condition.');
      });
      final ai = AiAssistant(client: client, apiKey: 'test-key');
      expect(
        await ai.productDescription(title: 'Laptop', condition: 'Used'),
        'A used laptop in good condition.',
      );
      client.close();
    },
  );

  test(
    'Arabic description is requested and decoded without corruption',
    () async {
      AppLocale.current = AppLanguage.arabic;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['messages'][1]['content'], contains('Language: Arabic'));
        return answer('لابتوب مستعمل بحالة جيدة.');
      });
      final ai = AiAssistant(client: client, apiKey: 'test-key');
      expect(
        await ai.productDescription(title: 'Laptop'),
        'لابتوب مستعمل بحالة جيدة.',
      );
      client.close();
    },
  );

  test('tags use JSON mode and accept a fenced JSON response', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['response_format'], {'type': 'json_object'});
      return answer('```json\n{"tags":["Laptop","#computer"]}\n```');
    });
    final ai = AiAssistant(client: client, apiKey: 'test-key');
    expect(await ai.tags(title: 'Laptop'), ['laptop', 'computer']);
    client.close();
  });

  test('announcement decodes title and body', () async {
    final client = MockClient(
      (_) async => answer('{"title":"Hello","body":"Welcome back."}'),
    );
    final ai = AiAssistant(client: client, apiKey: 'test-key');
    expect(await ai.announcement(topic: 'Welcome'), (
      title: 'Hello',
      body: 'Welcome back.',
    ));
    client.close();
  });

  for (final content in [null, '', '   ']) {
    test(
      'empty content is an error, not a successful draft: $content',
      () async {
        final client = MockClient((_) async => answer(content));
        final ai = AiAssistant(client: client, apiKey: 'test-key');
        await expectLater(
          ai.productDescription(title: 'Laptop'),
          throwsA(isA<SouqException>()),
        );
        client.close();
      },
    );
  }

  test('truncated JSON is never silently inserted in a form', () async {
    final client = MockClient(
      (_) async => answer('{"tags":["laptop', finish: 'length'),
    );
    final ai = AiAssistant(client: client, apiKey: 'test-key');
    await expectLater(ai.tags(title: 'Laptop'), throwsA(isA<SouqException>()));
    client.close();
  });

  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status gives a safe user-facing error', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"upstream"}', status),
      );
      final ai = AiAssistant(client: client, apiKey: 'test-key');
      await expectLater(
        ai.serviceBrief(serviceTitle: 'Printing'),
        throwsA(isA<SouqException>()),
      );
      client.close();
    });
  }

  test('network failures are handled', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    final ai = AiAssistant(client: client, apiKey: 'test-key');
    await expectLater(
      ai.productDescription(title: 'Laptop'),
      throwsA(isA<SouqException>()),
    );
    client.close();
  });

  test('timeout does not leave the form waiting indefinitely', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final ai = AiAssistant(
      client: client,
      apiKey: 'test-key',
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      ai.productDescription(title: 'Laptop'),
      throwsA(isA<SouqException>()),
    );
    client.close();
  });

  test('missing credentials never sends a request', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return answer('unused');
    });
    final ai = AiAssistant(client: client, apiKey: '');
    await expectLater(
      ai.productDescription(title: 'Laptop'),
      throwsA(isA<SouqException>()),
    );
    expect(called, isFalse);
    client.close();
  });
}
