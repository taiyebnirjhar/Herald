import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/hermes_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _key = 'test-key-0123456789abcdef';

Stream<List<int>> _bytes(String text) => Stream.value(utf8.encode(text));

void main() {
  group('parseDeltas', () {
    test('yields each text piece in order and stops at [DONE]', () async {
      const sse = 'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n'
          ': keep-alive\n\n'
          'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n'
          'data: [DONE]\n\n'
          'data: {"choices":[{"delta":{"content":"ignored"}}]}\n\n';

      final pieces = await HermesApi.parseDeltas(_bytes(sse)).toList();

      expect(pieces, ['Hel', 'lo']);
    });

    test('skips events without text, bad shapes and empty pieces', () async {
      const sse = 'data: {"choices":[{"delta":{"role":"assistant"}}]}\n'
          'data: {"choices":[]}\n'
          'data: {"choices":[{"delta":{"content":""}}]}\n'
          'data: "not an object"\n'
          'data:\n'
          'data: {"choices":[{"delta":{"content":"ok"}}]}\n'
          'data: [DONE]\n';

      expect(await HermesApi.parseDeltas(_bytes(sse)).toList(), ['ok']);
    });

    test('works when a line is split across chunks', () async {
      final chunks = [
        utf8.encode('data: {"choices":[{"delta":{"con'),
        utf8.encode('tent":"split"}}]}\ndata: [DONE]\n'),
      ];
      final pieces = await HermesApi.parseDeltas(Stream.fromIterable(chunks)).toList();

      expect(pieces, ['split']);
    });
  });

  group('reply', () {
    test('sends the key, the default model and streams the reply', () async {
      late http.BaseRequest seen;
      final client = MockClient.streaming((request, _) async {
        seen = request;
        final body = 'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\ndata: [DONE]\n';
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });
      final api = HermesApi(port: 8642, apiKey: _key, client: client);

      final pieces = await api
          .reply(const [ChatTurn(role: 'user', content: 'hello')])
          .toList();

      expect(pieces, ['Hi']);
      expect(seen.url.toString(), 'http://127.0.0.1:8642/v1/chat/completions');
      expect(seen.headers['Authorization'], 'Bearer $_key');
      final sent = jsonDecode((seen as http.Request).body) as Map<String, dynamic>;
      expect(sent['model'], 'hermes-agent');
      expect(sent['stream'], isTrue);
      expect(sent['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('a rejected key gives a plain message that does not show the key', () async {
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(Stream.value(utf8.encode('{"error":"nope"}')), 401);
      });
      final api = HermesApi(port: 8642, apiKey: _key, client: client);

      await expectLater(
        api.reply(const [ChatTurn(role: 'user', content: 'x')]).toList(),
        throwsA(
          isA<HermesApiException>()
              .having((e) => e.message, 'message', contains("didn't accept the key"))
              .having((e) => e.message, 'message', isNot(contains(_key))),
        ),
      );
    });

    test('no answer from the server gives a plain message', () async {
      final client = MockClient.streaming((_, _) async => throw http.ClientException('refused'));
      final api = HermesApi(port: 8642, apiKey: _key, client: client);

      await expectLater(
        api.reply(const [ChatTurn(role: 'user', content: 'x')]).toList(),
        throwsA(isA<HermesApiException>().having((e) => e.message, 'message', contains("isn't answering"))),
      );
    });
  });

  group('safety', () {
    test('no key means nothing is sent at all', () async {
      var sent = 0;
      final client = MockClient.streaming((_, _) async {
        sent++;
        return http.StreamedResponse(Stream.value(utf8.encode('data: [DONE]\n')), 200);
      });
      final api = HermesApi(port: 8642, apiKey: '', client: client);

      await expectLater(
        api.reply(const [ChatTurn(role: 'user', content: 'secret question')]).toList(),
        throwsA(isA<HermesApiException>().having((e) => e.message, 'message', contains("isn't running"))),
      );
      expect(sent, 0);
    });

    test('a finish_reason of error is shown as an error, not an empty reply', () async {
      const sse = 'data: {"choices":[{"delta":{},"finish_reason":"error"}]}\n\n'
          'data: [DONE]\n';

      await expectLater(
        HermesApi.parseDeltas(Stream.value(utf8.encode(sse))).toList(),
        throwsA(isA<HermesApiException>().having((e) => e.message, 'message', contains('stopped with an error'))),
      );
    });
  });

  group('isUp', () {
    test('true when the health check answers 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response('{"status":"ok"}', 200);
      });
      expect(await HermesApi(port: 8642, apiKey: _key, client: client).isUp(), isTrue);
    });

    test('false when nothing answers', () async {
      final client = MockClient((_) async => throw http.ClientException('refused'));
      expect(await HermesApi(port: 8642, apiKey: _key, client: client).isUp(), isFalse);
    });
  });
}
