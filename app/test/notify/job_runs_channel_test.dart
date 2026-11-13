import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/engine_connection.dart';
import 'package:herald/notify/job_runs_channel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FixedConnection implements EngineConnection {
  @override
  Future<EngineAddress> address() async => const EngineAddress(port: 8642, key: 'test-key-1234567890');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesJobListSource', () {
    test('asks for all jobs on loopback with the key as a bearer header', () async {
      late http.Request seen;
      final source = HermesJobListSource(
        connection: _FixedConnection(),
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'jobs': []}), 200);
        }),
      );
      await source.fetch();
      expect(seen.url.host, '127.0.0.1');
      expect(seen.url.port, 8642);
      expect(seen.url.path, '/api/jobs');
      expect(seen.url.queryParameters, {'include_disabled': 'true'});
      expect(seen.headers['Authorization'], 'Bearer test-key-1234567890');
    });

    test('reads the jobs and their newest runs', () async {
      final source = HermesJobListSource(
        connection: _FixedConnection(),
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'jobs': [
                  {
                    'id': 'job-1',
                    'name': 'Morning news',
                    'prompt': 'Summarise',
                    'latest_execution': {'id': 'exec-1', 'status': 'completed'},
                  },
                  'not a job',
                ],
              }),
              200,
            )),
      );
      final jobs = await source.fetch();
      expect(jobs.length, 1);
      expect(jobs.single.jobId, 'job-1');
      expect(jobs.single.status, 'completed');
    });

    test('a non-success answer throws, without the key in the message', () async {
      final source = HermesJobListSource(
        connection: _FixedConnection(),
        client: MockClient((_) async => http.Response('nope', 401)),
      );
      await expectLater(
        source.fetch(),
        throwsA(predicate((e) => !e.toString().contains('test-key'))),
      );
    });

    test('an answer that is not a job list gives no jobs', () async {
      final source = HermesJobListSource(
        connection: _FixedConnection(),
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      expect(await source.fetch(), isEmpty);
    });
  });

  group('MethodChannelRunBridge', () {
    const channel = MethodChannel('herald/notify');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call);
          if (call.method == 'getNotified') return 'exec-9';
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('reads, writes and shows through the herald/notify channel', () async {
      final bridge = MethodChannelRunBridge(channel);
      expect(await bridge.lastNotified('job-1'), 'exec-9');
      await bridge.setLastNotified('job-1', 'exec-10');
      await bridge.show(id: 7, title: 'Job finished', body: 'Morning news finished.');

      expect(calls.map((c) => c.method), ['getNotified', 'setNotified', 'show']);
      expect(calls[0].arguments, {'jobId': 'job-1'});
      expect(calls[1].arguments, {'jobId': 'job-1', 'value': 'exec-10'});
      expect(calls[2].arguments, {'id': 7, 'title': 'Job finished', 'body': 'Morning news finished.'});
    });
  });
}
