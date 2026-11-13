import 'dart:convert';

import 'package:http/http.dart' as http;

/// A scheduled job, as Hermes lists it (`GET /api/jobs`). See docs/HERMES_API.md.
class ScheduledJob {
  const ScheduledJob({
    required this.id,
    required this.name,
    required this.paused,
    required this.state,
    required this.scheduleText,
    required this.prompt,
  });

  final String id;
  final String name;
  final bool paused;

  /// Hermes's own state word, such as "scheduled" or "completed". Shown as plain text.
  final String state;

  /// How often it runs, in Hermes's words (for example "every day at 9:00").
  final String scheduleText;
  final String prompt;

  /// Reads each field only if it has the expected type, so one odd value cannot break the list.
  factory ScheduledJob.fromJson(Map<String, dynamic> json) => ScheduledJob(
        id: _text(json['id']) ?? '',
        name: _text(json['name']) ?? 'Untitled job',
        paused: json['paused'] == true,
        state: _text(json['state']) ?? '',
        scheduleText: _text(json['schedule_display']) ?? '',
        prompt: _text(json['prompt']) ?? '',
      );

  static String? _text(Object? value) => value is String ? value : null;
}

/// A problem the player can read. Never contains the key.
class JobsApiException implements Exception {
  const JobsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lists and controls Hermes's scheduled jobs on this phone (WBS 0.3.5).
class JobsApi {
  JobsApi({required this.port, required this.apiKey, http.Client? client, this.host = '127.0.0.1'})
      : _client = client ?? http.Client();

  final String host;
  final int port;
  final String apiKey;
  final http.Client _client;

  Uri _uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<List<ScheduledJob>> list() async {
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/api/jobs',
      queryParameters: {'include_disabled': 'true'},
    );
    final response = await _send(() => _client.get(uri, headers: _headers));
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const JobsApiException('Hermes sent an answer Herald could not read. Try again.');
    }
    final jobs = body is Map ? body['jobs'] : null;
    if (jobs is! List) return const [];
    return [
      for (final j in jobs)
        if (j is Map<String, dynamic> && j['id'] is String && (j['id'] as String).isNotEmpty)
          ScheduledJob.fromJson(j),
    ];
  }

  Future<void> pause(String id) => _post('/api/jobs/${Uri.encodeComponent(id)}/pause');

  Future<void> resume(String id) => _post('/api/jobs/${Uri.encodeComponent(id)}/resume');

  /// Runs the job now, once.
  Future<void> runNow(String id) => _post('/api/jobs/${Uri.encodeComponent(id)}/run');

  Future<void> _post(String path) async {
    await _send(() => _client.post(_uri(path), headers: _headers, body: '{}'));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    // No key means Hermes is not confirmed running. Send nothing in that case.
    if (apiKey.isEmpty) {
      throw const JobsApiException("Hermes isn't running. Start it first.");
    }
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const JobsApiException("Hermes isn't answering. Start Hermes and try again.");
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const JobsApiException("Hermes didn't accept the key. Restart Hermes from the chat screen.");
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JobsApiException("Hermes returned an error (code ${response.statusCode}).");
    }
    return response;
  }

  void close() => _client.close();
}
