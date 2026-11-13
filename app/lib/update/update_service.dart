import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../downloads/background_downloader.dart';
import 'app_update.dart';
import 'update_exception.dart';

export 'update_exception.dart';

/// Finds the newest Herald release and downloads its APK.
///
/// The version comes from github.com pages (not the API), so there is no
/// per-address limit. The APK downloads in the background, through the same
/// downloader as every other download in the app.
class UpdateService {
  UpdateService({
    http.Client? client,
    BackgroundDownloader? downloader,
    this.owner = 'taiyebnirjhar',
    this.repo = 'Herald',
    required this.downloadsDir,
  })  : _client = client ?? http.Client(),
        downloader = downloader ?? MethodChannelDownloader();

  final http.Client _client;
  final String owner;
  final String repo;

  /// Downloads in the background (Android's download manager).
  final BackgroundDownloader downloader;

  /// Where verified APKs are kept. Inside the app's cache folder, which is
  /// the folder the FileProvider shares with Android's installer.
  final Future<Directory> Function() downloadsDir;

  Uri get _latestUrl => Uri.https('github.com', '/$owner/$repo/releases/latest');

  /// The newest release, or null when there is none yet.
  /// Throws [UpdateException] when GitHub can't be reached.
  Future<AppUpdate?> latestRelease() async {
    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', _latestUrl)
        ..followRedirects = false
        ..headers['User-Agent'] = 'Herald-app';
      response = await _client.send(request).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const UpdateException(
        "Couldn't reach GitHub. Check the internet connection and try again.",
      );
    }
    await response.stream.drain<void>();

    if (response.statusCode == 404) return null; // no release yet
    if (response.statusCode >= 300 && response.statusCode < 400) {
      // GitHub sends the newest tag in the redirect's Location header.
      final location = response.headers['location'];
      final tag = location == null ? null : AppUpdate.tagFromLocation(location);
      if (tag == null) {
        throw const UpdateException("Couldn't read the newest version from GitHub.");
      }
      return AppUpdate.fromTag(owner: owner, repo: repo, tag: tag);
    }
    throw UpdateException(
      'GitHub answered ${response.statusCode}. Try again later.',
    );
  }

  /// Downloads [update] in the background, reporting progress from 0.0 to 1.0.
  /// The file must match the SHA-256 in its `.sha256` file; a file that doesn't
  /// match is deleted and an [UpdateException] is thrown.
  Future<File> download(
    AppUpdate update, {
    void Function(double fraction)? onProgress,
  }) async {
    final dir = await downloadsDir();
    await _clearOldDownloads(dir, keep: update.version);
    final expected = await _expectedSha256(update);

    final name = 'herald-${update.version}.apk';
    await downloader.start(
      url: update.apkUrl,
      name: name,
      title: 'Herald ${update.version}',
    );
    final source = await downloader.waitFor(
      name,
      onProgress: (s) => onProgress?.call(s.fraction),
    );

    final file = File('${dir.path}/$name');
    if (await file.exists()) await file.delete();
    await File(source).copy(file.path);
    await File(source).delete();

    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != expected) {
      await file.delete();
      throw const UpdateException(
        "The file didn't pass the safety check, so it was not installed. Try again.",
      );
    }
    onProgress?.call(1.0);
    return file;
  }

  Future<String> _expectedSha256(AppUpdate update) async {
    final http.Response r;
    try {
      r = await _client
          .get(Uri.parse(update.sha256Url), headers: const {'User-Agent': 'Herald-app'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const UpdateException(
        "Couldn't reach GitHub for the checksum. Check the connection and try again.",
      );
    }
    if (r.statusCode == 404) {
      throw const UpdateException(
        "This update has no checksum file, so it can't be checked. Install it from the Releases page.",
      );
    }
    if (r.statusCode != 200) {
      throw UpdateException('GitHub answered ${r.statusCode} for the checksum.');
    }
    final hash = AppUpdate.sha256FromFile(utf8.decode(r.bodyBytes));
    if (hash == null) {
      throw const UpdateException('The checksum file is not in the right format.');
    }
    return hash;
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
