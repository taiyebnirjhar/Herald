import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../chat/engine_connection.dart';
import 'job_run_watcher.dart';
import 'job_runs.dart';

/// Lists the scheduled jobs from Hermes (`GET /api/jobs`) on this phone.
class HermesJobListSource implements JobListSource {
  HermesJobListSource({
    required this.connection,
    http.Client? client,
    this.host = '127.0.0.1',
  }) : _client = client ?? http.Client();

  final EngineConnection connection;
  final String host;
  final http.Client _client;

  @override
  Future<List<JobRunSnapshot>> fetch() async {
    final address = await connection.address();
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: address.port,
      path: '/api/jobs',
      queryParameters: {'include_disabled': 'true'},
    );
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer ${address.key}'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Jobs not available (code ${response.statusCode}).');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final jobs = body['jobs'];
    if (jobs is! List) return const [];
    return [
      for (final job in jobs)
        if (job is Map<String, dynamic>) JobRunSnapshot.fromJson(job),
    ];
  }
}

/// Saved run state and notifications, through Android (`JobNotifyChannel.kt`).
class MethodChannelRunBridge implements RunStateStore, RunNotifier {
  MethodChannelRunBridge([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/notify';
  final MethodChannel _channel;

  @override
  Future<String?> lastNotified(String jobId) =>
      _channel.invokeMethod<String>('getNotified', {'jobId': jobId});

  @override
  Future<void> setLastNotified(String jobId, String value) =>
      _channel.invokeMethod<void>('setNotified', {'jobId': jobId, 'value': value});

  @override
  Future<void> show({required int id, required String title, required String body}) =>
      _channel.invokeMethod<void>('show', {'id': id, 'title': title, 'body': body});
}
