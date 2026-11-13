import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/engine_connection.dart';
import 'package:herald/jobs/jobs_api.dart';
import 'package:herald/jobs/jobs_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeConnection implements EngineConnection {
  @override
  Future<EngineAddress> address() async =>
      const EngineAddress(port: 8642, key: 'key-0123456789abcdef');
}

Future<void> _open(WidgetTester tester, MockClient client) async {
  await tester.pumpWidget(
    MaterialApp(
      home: JobsPage(
        connection: _FakeConnection(),
        createApi: (a) => JobsApi(port: a.port, apiKey: a.key, client: client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MockClient _server({required List<Map<String, dynamic>> jobs, List<String>? calls}) {
  return MockClient((request) async {
    calls?.add('${request.method} ${request.url.path}');
    if (request.method == 'GET') return http.Response(jsonEncode({'jobs': jobs}), 200);
    return http.Response('{}', 200);
  });
}

void main() {
  testWidgets('lists jobs with their schedule and On or Paused', (tester) async {
    await _open(
      tester,
      _server(jobs: [
        {'id': 'j1', 'name': 'Morning brief', 'paused': false, 'schedule_display': 'every day at 9:00'},
        {'id': 'j2', 'name': 'Old check', 'paused': true, 'schedule_display': 'every hour'},
      ]),
    );

    expect(find.text('Morning brief'), findsOneWidget);
    expect(find.text('every day at 9:00'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Old check'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('no jobs shows a plain message', (tester) async {
    await _open(tester, _server(jobs: []));

    expect(find.textContaining('No scheduled jobs yet'), findsOneWidget);
  });

  testWidgets('Run now calls the run route and says so', (tester) async {
    final calls = <String>[];
    await _open(
      tester,
      _server(
        jobs: [
          {'id': 'j1', 'name': 'Morning brief', 'paused': false, 'schedule_display': 'daily'},
        ],
        calls: calls,
      ),
    );
    calls.clear();

    await tester.tap(find.text('Run now'));
    await tester.pumpAndSettle();

    expect(calls, contains('POST /api/jobs/j1/run'));
    expect(find.text('Started: Morning brief'), findsOneWidget);
  });

  testWidgets('a paused job shows Resume and calls the resume route', (tester) async {
    final calls = <String>[];
    await _open(
      tester,
      _server(
        jobs: [
          {'id': 'j2', 'name': 'Old check', 'paused': true, 'schedule_display': 'hourly'},
        ],
        calls: calls,
      ),
    );
    calls.clear();

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(calls, contains('POST /api/jobs/j2/resume'));
  });

  testWidgets('when Hermes is not answering: a plain message and Try again', (tester) async {
    final client = MockClient((_) async => throw http.ClientException('refused'));
    await _open(tester, client);

    expect(find.textContaining("isn't answering"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
