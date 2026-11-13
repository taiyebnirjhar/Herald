import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:herald/jobs/jobs_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _key = 'test-key-0123456789abcdef';

JobsApi _api(MockClient client) => JobsApi(port: 8642, apiKey: _key, client: client);

void main() {
  test('list reads name, paused flag, schedule and prompt, and asks for disabled jobs too', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'jobs': [
            {
              'id': 'j1',
              'name': 'Morning brief',
              'paused': false,
              'state': 'scheduled',
              'schedule_display': 'every day at 9:00',
              'prompt': 'Summarise my notes',
            },
            {'id': 'j2', 'name': 'Old check', 'paused': true, 'schedule_display': 'every hour'},
          ],
        }),
        200,
      );
    });

    final jobs = await _api(client).list();

    expect(seen.url.path, '/api/jobs');
    expect(seen.url.queryParameters['include_disabled'], 'true');
    expect(seen.headers['Authorization'], 'Bearer $_key');
    expect(jobs.length, 2);
    expect(jobs.first.name, 'Morning brief');
    expect(jobs.first.scheduleText, 'every day at 9:00');
    expect(jobs.first.paused, isFalse);
    expect(jobs.last.paused, isTrue);
  });

  test('pause, resume and run-now call the matching routes with POST', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      paths.add(request.url.path);
      return http.Response('{}', 200);
    });
    final api = _api(client);

    await api.pause('j1');
    await api.resume('j1');
    await api.runNow('j1');

    expect(paths, ['/api/jobs/j1/pause', '/api/jobs/j1/resume', '/api/jobs/j1/run']);
  });

  test('a rejected key gives a plain message that does not show the key', () async {
    final client = MockClient((_) async => http.Response('{}', 401));

    await expectLater(
      _api(client).list(),
      throwsA(
        isA<JobsApiException>()
            .having((e) => e.message, 'message', contains("didn't accept the key"))
            .having((e) => e.message, 'message', isNot(contains(_key))),
      ),
    );
  });

  test('no answer from Hermes gives a plain message', () async {
    final client = MockClient((_) async => throw http.ClientException('refused'));

    await expectLater(
      _api(client).runNow('j1'),
      throwsA(isA<JobsApiException>().having((e) => e.message, 'message', contains("isn't answering"))),
    );
  });

  test('other errors show the status code', () async {
    final client = MockClient((_) async => http.Response('{}', 500));

    await expectLater(
      _api(client).pause('j1'),
      throwsA(isA<JobsApiException>().having((e) => e.message, 'message', contains('code 500'))),
    );
  });
}
