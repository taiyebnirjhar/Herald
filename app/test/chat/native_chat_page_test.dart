import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/engine_connection.dart';
import 'package:herald/chat/hermes_api.dart';
import 'package:herald/chat/native_chat_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeConnection implements EngineConnection {
  _FakeConnection({this.fail = false, this.key = 'key-0123456789abcdef'});
  final bool fail;

  /// Empty means Android has not confirmed that Hermes is running.
  final String key;

  @override
  Future<EngineAddress> address() async {
    if (fail) throw StateError('no connection details');
    return EngineAddress(port: 8642, key: key);
  }
}

http.StreamedResponse _text(String body, int status) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

const _replyOk = 'data: {"choices":[{"delta":{"content":"Hello "}}]}\n\n'
    'data: {"choices":[{"delta":{"content":"there"}}]}\n\n'
    'data: [DONE]\n\n';

/// A mock server: /health answers [healthy]; chat answers with [chat].
HermesApi Function(EngineAddress) _server({
  required bool healthy,
  required Future<http.StreamedResponse> Function(http.BaseRequest) chat,
}) {
  final client = MockClient.streaming((request, _) async {
    if (request.url.path == '/health') {
      return _text('{"status":"ok"}', healthy ? 200 : 503);
    }
    return chat(request);
  });
  return (a) => HermesApi(port: a.port, apiKey: a.key, client: client);
}

Future<void> _open(
  WidgetTester tester, {
  required HermesApi Function(EngineAddress) createApi,
  EngineConnection? connection,
  Future<void> Function()? startHermes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NativeChatPage(
        connection: connection ?? _FakeConnection(),
        createApi: createApi,
        startHermes: startHermes,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('when Hermes is up: greeting, input ready, no banner', (tester) async {
    await _open(
      tester,
      createApi: _server(healthy: true, chat: (_) async => _text(_replyOk, 200)),
    );

    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Ask Herald anything'), findsOneWidget);
    expect(find.text('Hermes is not running.'), findsNothing);
  });

  testWidgets('sending a message shows it and the streamed reply', (tester) async {
    String? sentBody;
    await _open(
      tester,
      createApi: _server(
        healthy: true,
        chat: (request) async {
          sentBody = utf8.decode((request as http.Request).bodyBytes);
          return _text(_replyOk, 200);
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hi there');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(sentBody, contains('"stream":true'));
    expect(sentBody, contains('"Hi there"'));
  });

  testWidgets('an error shows the plain message and Try again, which asks again', (tester) async {
    var calls = 0;
    await _open(
      tester,
      createApi: _server(
        healthy: true,
        chat: (_) async {
          calls++;
          return calls == 1 ? _text('{"error":"x"}', 500) : _text(_replyOk, 200);
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hermes returned an error'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Hello there'), findsOneWidget);
  });

  testWidgets('when Hermes is not running: banner with Start Hermes, which starts it', (tester) async {
    var started = 0;
    var healthy = false;
    await _open(
      tester,
      createApi: (a) {
        final client = MockClient.streaming((request, _) async {
          if (request.url.path == '/health') {
            return _text('{}', healthy ? 200 : 503);
          }
          return _text(_replyOk, 200);
        });
        return HermesApi(port: a.port, apiKey: a.key, client: client);
      },
      startHermes: () async {
        started++;
        healthy = true;
      },
    );

    expect(find.text('Hermes is not running.'), findsOneWidget);
    await tester.tap(find.text('Start Hermes'));
    await tester.pumpAndSettle();

    expect(started, 1);
    expect(find.text('Hermes is not running.'), findsNothing);
  });

  testWidgets('no confirmed key: the banner shows and nothing is sent', (tester) async {
    var posts = 0;
    await _open(
      tester,
      connection: _FakeConnection(key: ''),
      createApi: _server(
        healthy: true,
        chat: (_) async {
          posts++;
          return _text(_replyOk, 200);
        },
      ),
    );

    expect(find.text('Hermes is not running.'), findsOneWidget);
    expect(posts, 0);
  });

  testWidgets('when the connection details cannot be read: plain message and Try again', (tester) async {
    await _open(
      tester,
      connection: _FakeConnection(fail: true),
      createApi: _server(healthy: true, chat: (_) async => _text(_replyOk, 200)),
    );

    expect(find.textContaining("couldn't read its connection details"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
