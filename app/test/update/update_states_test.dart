import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/update/app_installer.dart';
import 'package:herald/update/update_controller.dart';
import 'package:herald/update/update_service.dart';
import '../downloads/fake_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Installer implements AppInstaller {
  _Installer({this.canInstallNow = true, this.throwOnInstall = false});
  bool canInstallNow;
  final bool throwOnInstall;
  final installs = <String>[];

  @override
  Future<InstalledVersion> installedVersion() async =>
      const InstalledVersion(versionName: '0.1.0', versionCode: 1);
  @override
  Future<bool> canInstall() async => canInstallNow;
  @override
  Future<String> cacheDir() async => Directory.systemTemp.path;
  @override
  Future<InstallResult> install(String apkPath) async {
    if (throwOnInstall) throw StateError('no installer');
    installs.add(apkPath);
    return canInstallNow ? InstallResult.started : InstallResult.needsPermission;
  }
}

final _apk = utf8.encode('apk bytes for states');
final _sha = sha256.convert(_apk).toString();

/// Routes GitHub's three pages. [tag] null means no release yet.
Future<http.Response> _github(http.Request r,
    {String? tag = 'v0.2.0', String? sha, int? apkStatus}) async {
  if (r.url.path == '/taiyebnirjhar/Herald/releases/latest') {
    if (tag == null) return http.Response('', 404);
    return http.Response('', 302, headers: {
      'location': 'https://github.com/taiyebnirjhar/Herald/releases/tag/$tag',
    });
  }
  if (r.url.path.endsWith('.sha256')) {
    return http.Response('${sha ?? _sha}  herald-0.2.0-arm64.apk\n', 200);
  }
  return http.Response.bytes(_apk, apkStatus ?? 200);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('herald_states'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  UpdateController make({
    String? tag = 'v0.2.0',
    String? sha,
    int? apkStatus,
    _Installer? installer,
  }) =>
      UpdateController(
        service: UpdateService(
          client: MockClient((r) => _github(r, tag: tag, sha: sha, apkStatus: apkStatus)),
          downloader: FakeDownloader(dir: dir, bytes: _apk),
          downloadsDir: () async => dir,
        ),
        installer: installer ?? _Installer(),
      );

  test('starts idle, and init reads the installed version', () async {
    final c = make();
    expect(c.step, UpdateStep.idle);
    await c.init();
    expect(c.installedName, '0.1.0');
  });

  test('init never throws: an unreadable version says unknown', () async {
    final c = UpdateController(
      service: UpdateService(
        client: MockClient((_) async => http.Response('', 404)),
        downloader: FakeDownloader(dir: dir, bytes: _apk),
        downloadsDir: () async => dir,
      ),
      installer: _ThrowingVersionInstaller(),
    );
    await c.init();
    expect(c.installedName, 'unknown');
  });

  test('no release yet is up to date, not an error', () async {
    final c = make(tag: null);
    await c.init();
    await c.checkForUpdate();
    expect(c.step, UpdateStep.upToDate);
    expect(c.update, isNull);
  });

  test('an older release is not offered', () async {
    final c = make(tag: 'v0.0.9');
    await c.init();
    await c.checkForUpdate();
    expect(c.step, UpdateStep.upToDate);
  });

  test('a check is ignored while one is already running', () async {
    final c = make();
    await c.init();
    final first = c.checkForUpdate();
    expect(c.busy, isTrue);
    await c.checkForUpdate(); // no second request, no exception
    await first;
    expect(c.step, UpdateStep.available);
  });

  test('downloadAndInstall does nothing without an offered update', () async {
    final installer = _Installer();
    final c = make(installer: installer);
    await c.init();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.idle);
    expect(installer.installs, isEmpty);
  });

  test('a successful download reaches the installer', () async {
    final installer = _Installer();
    final c = make(installer: installer);
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.installing);
    expect(c.progress, 1.0);
    expect(installer.installs.single, endsWith('herald-0.2.0.apk'));
  });

  test('a download with a bad checksum fails with the reason and no install', () async {
    final installer = _Installer();
    final c = make(sha: '1' * 64, installer: installer);
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.failed);
    expect(c.message, contains("didn't pass the safety check"));
    expect(installer.installs, isEmpty);
    expect(c.update, isNotNull, reason: 'Try again keeps the same update');
  });

  test('a release without a checksum file is refused', () async {
    final c = UpdateController(
      service: UpdateService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('.sha256')) return http.Response('', 404);
          return _github(r);
        }),
        downloader: FakeDownloader(dir: dir, bytes: _apk),
        downloadsDir: () async => dir,
      ),
      installer: _Installer(),
    );
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.failed);
    expect(c.message, contains('no checksum file'));
  });

  test('no permission to install goes to the permission step, then installs', () async {
    final installer = _Installer(canInstallNow: false);
    final c = make(installer: installer);
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.needsPermission);

    installer.canInstallNow = true;
    await c.install();
    expect(c.step, UpdateStep.installing);
  });

  test('an installer that cannot open says so and offers a fallback', () async {
    final c = make(installer: _Installer(throwOnInstall: true));
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.failed);
    expect(c.message, contains("installer didn't open"));
  });

  test('install does nothing before a file is downloaded', () async {
    final installer = _Installer();
    final c = make(installer: installer);
    await c.install();
    expect(installer.installs, isEmpty);
    expect(c.step, UpdateStep.idle);
  });

  test('a failed background download is reported with its reason', () async {
    final c = UpdateController(
      service: UpdateService(
        client: MockClient((r) => _github(r)),
        downloader: FakeDownloader(dir: dir, failWith: 'Download failed (code 500)'),
        downloadsDir: () async => dir,
      ),
      installer: _Installer(),
    );
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();
    expect(c.step, UpdateStep.failed);
    expect(c.message, contains('code 500'));
  });
}

class _ThrowingVersionInstaller extends _Installer {
  @override
  Future<InstalledVersion> installedVersion() async => throw StateError('no package info');
}
