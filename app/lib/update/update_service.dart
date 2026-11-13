import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'app_update.dart';

/// A problem the player can read on screen.
class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Finds the newest Herald release and downloads its APK.
class UpdateService {
  UpdateService({
    http.Client? client,
    this.owner = 'taiyebnirjhar',
    this.repo = 'Herald',
    required this.downloadsDir,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String owner;
  final String repo;

  /// Where APKs are kept. Must be inside the app's cache folder, which is
  /// the folder the FileProvider shares with Android's installer.
  final Future<Directory> Function() downloadsDir;

  Uri get _latestUrl =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  /// The newest release that is a usable APK, or null when there is none.
  /// Throws [UpdateException] when GitHub can't be reached.
  Future<AppUpdate?> latestRelease() async {
    final http.Response response;
    try {
      response = await _client.get(
        _latestUrl,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'Herald-app',
        },
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const UpdateException(
        "Couldn't reach GitHub. Check the internet connection and try again.",
      );
    }
    if (response.statusCode == 404) return null; // no release yet
    if (response.statusCode != 200) {
      throw UpdateException(
        'GitHub answered ${response.statusCode}. Try again later.',
      );
    }
    return AppUpdate.fromReleaseJson(utf8.decode(response.bodyBytes));
  }

  /// Downloads [update] into the downloads folder, reporting progress from
  /// 0.0 to 1.0. The file is checked against the SHA-256 from GitHub; a file
  /// that doesn't match is deleted and an [UpdateException] is thrown.
  Future<File> download(
    AppUpdate update, {
    void Function(double fraction)? onProgress,
  }) async {
    final dir = await downloadsDir();
    await _clearOldDownloads(dir, keep: update.version);
    final file = File('${dir.path}/herald-${update.version}.apk');
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', Uri.parse(update.apkUrl)))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const UpdateException(
        "The download didn't start. Check the connection and try again.",
      );
    }
    if (response.statusCode != 200) {
      throw UpdateException(
        'The download failed (GitHub answered ${response.statusCode}).',
      );
    }

    var received = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call((received / update.apkSize).clamp(0.0, 1.0));
      }
    } catch (_) {
      await sink.close();
      await partial.delete();
      throw const UpdateException(
        'The download stopped. Check the connection and try again.',
      );
    }
    await sink.close();

    if (received != update.apkSize) {
      await partial.delete();
      throw const UpdateException(
        'The download was incomplete. Try again.',
      );
    }

    final digest = await sha256.bind(partial.openRead()).first;
    if (digest.toString() != update.sha256) {
      await partial.delete();
      throw const UpdateException(
        "The file didn't pass the safety check, so it was not installed. Try again.",
      );
    }

    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
    return file;
  }

  Future<void> _clearOldDownloads(Directory dir, {required String keep}) async {
    await for (final entity in dir.list()) {
      if (entity is File &&
          !entity.path.endsWith('herald-$keep.apk') &&
          entity.path.contains('herald-')) {
        await entity.delete();
      }
    }
  }

  void close() => _client.close();
}
