import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One message in the conversation, as the API server expects it.
class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// A problem the player can read. The text never contains the key.
class HermesApiException implements Exception {
  const HermesApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to Hermes's API server on this phone (WBS 6.2). Replies stream in as they are written.
/// Only 127.0.0.1 is used (PLAN.md D7); the key is sent on every request.
class HermesApi {
  HermesApi({
    required this.port,
    required this.apiKey,
    http.Client? client,
    this.host = '127.0.0.1',
  }) : _client = client ?? http.Client();

  /// The gateway's virtual model: "the Hermes default", as the API server documents it.
  static const model = 'hermes-agent';

  final String host;
  final int port;
  final String apiKey;
  final http.Client _client;

  Uri _uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  /// True when the API server answers its health check.
  Future<bool> isUp() async {
    try {
      final response = await _client.get(_uri('/health')).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Streams the reply to [turns], piece by piece. Throws [HermesApiException] on a problem.
  Stream<String> reply(List<ChatTurn> turns) async* {
    final request = http.Request('POST', _uri('/v1/chat/completions'))
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': turns.map((t) => t.toJson()).toList(),
      });

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const HermesApiException("Hermes isn't answering. Check the Hermes switch on the Home screen.");
    }
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw HermesApiException(_describe(response.statusCode, body));
    }
    yield* parseDeltas(response.stream);
  }

  /// Turns the server's event stream into text pieces. Ends at `[DONE]`.
  static Stream<String> parseDeltas(Stream<List<int>> bytes) async* {
    final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') return;
      final event = jsonDecode(data);
      if (event is! Map) continue;
      final choices = event['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final first = choices.first;
      final delta = first is Map ? first['delta'] : null;
      final piece = delta is Map ? delta['content'] : null;
      if (piece is String && piece.isNotEmpty) yield piece;
    }
  }

  static String _describe(int status, String body) {
    if (status == 401 || status == 403) {
      return "Hermes didn't accept the key. Restart Hermes from the Home screen.";
    }
    if (status == 503) {
      return 'Hermes is starting or has no model yet. Check the model in Settings.';
    }
    return 'Hermes returned an error (code $status).';
  }

  void close() => _client.close();
}
