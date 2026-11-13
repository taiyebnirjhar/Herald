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

class FakeInstaller implements AppInstaller {
  FakeInstaller({this.version = '0.1.0', this.permissionMissing = false});

  final String version;
  bool permissionMissing;
  final installed = <String>[];

  @override
  Future<InstalledVersion> installedVersion() async =>
      InstalledVersion(versionName: version, versionCode: 1);

  @override
  Future<bool> canInstall() async => !permissionMissing;

  @override
  Future<String> cacheDir() async => Directory.systemTemp.path;

  @override
  Future<InstallResult> install(String apkPath) async {
    installed.add(apkPath);
    return permissionMissing
        ? InstallResult.needsPermission
        : InstallResult.started;
  }
}

final _apk = utf8.encode('apk bytes');
final _sha = sha256.convert(_apk).toString();

/// GitHub's pages: the latest-release redirect, the checksum file and the APK.
http.Response _github(http.Request r, {String tag = 'v0.1.1', String? sha}) {
  if (r.url.path == '/taiyebnirjhar/Herald/releases/latest') {
    return http.Response('', 302, headers: {
      'location': 'https://github.com/taiyebnirjhar/Herald/releases/tag/$tag',
    });
  }
  if (r.url.path.endsWith('.sha256')) {
    return http.Response('${sha ?? _sha}  herald-0.1.1-arm64.apk\n', 200);
  }
  return http.Response.bytes(_apk, 200);
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('herald_ctrl_test'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  UpdateController controller({
    required http.Client client,
    required FakeInstaller installer,
  }) =>
      UpdateController(
        service: UpdateService(
          client: client,
          downloader: FakeDownloader(dir: dir, bytes: _apk),
          downloadsDir: () async => dir,
        ),
        installer: installer,
      );

  test('a newer release is offered; the same version is not', () async {
    var c = controller(
      client: MockClient((r) async => _github(r)),
      installer: FakeInstaller(),
    );
    await c.init();
    expect(c.installedName, '0.1.0');
    await c.checkForUpdate();
    expect(c.step, UpdateStep.available);
    expect(c.update?.version, '0.1.1');

    c = controller(
      client: MockClient((r) async => _github(r, tag: 'v0.1.0')),
      installer: FakeInstaller(),
    );
    await c.init();
    await c.checkForUpdate();
    expect(c.step, UpdateStep.upToDate);
  });

  test('no network: a plain message and a way to try again', () async {
    final c = controller(
      client: MockClient((_) async => throw const SocketLikeError()),
      installer: FakeInstaller(),
    );
    await c.init();
    await c.checkForUpdate();
    expect(c.step, UpdateStep.failed);
    expect(c.message, contains("Couldn't reach GitHub"));
    expect(c.update, isNull);
  });

  test('download, check and open the installer', () async {
    final installer = FakeInstaller();
    final c = controller(
      client: MockClient((request) async {
        return _github(request);
      }),
      installer: installer,
    );
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();

    expect(c.step, UpdateStep.installing);
    expect(installer.installed, hasLength(1));
    expect(installer.installed.single, endsWith('herald-0.1.1.apk'));
    expect(File(installer.installed.single).existsSync(), isTrue);
  });

  test('a bad checksum stops before the installer', () async {
    final installer = FakeInstaller();
    final c = controller(
      client: MockClient((request) async {
        return _github(request, sha: '0' * 64);
      }),
      installer: installer,
    );
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();

    expect(c.step, UpdateStep.failed);
    expect(installer.installed, isEmpty);
  });

  test('first install asks for the one-time permission', () async {
    final installer = FakeInstaller(permissionMissing: true);
    final c = controller(
      client: MockClient((request) async {
        return _github(request);
      }),
      installer: installer,
    );
    await c.init();
    await c.checkForUpdate();
    await c.downloadAndInstall();

    expect(c.step, UpdateStep.needsPermission);

    // After the player allows it in settings, the same button installs.
    installer.permissionMissing = false;
    await c.install();
    expect(c.step, UpdateStep.installing);
  });
}

/// Stands in for a network failure in the mock client.
class SocketLikeError implements Exception {
  const SocketLikeError();
}
