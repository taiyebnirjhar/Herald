import 'dart:io';

import 'package:herald/update/app_installer.dart';
import 'package:herald/update/update_controller.dart';
import 'package:herald/update/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An installer that reports version 0.1.0 and never touches Android.
class FakeInstaller implements AppInstaller {
  FakeInstaller({this.versionName = '0.1.0', this.throwOnVersion = false});

  final String versionName;
  final bool throwOnVersion;

  @override
  Future<InstalledVersion> installedVersion() async {
    if (throwOnVersion) throw StateError('no version from Android');
    return InstalledVersion(versionName: versionName, versionCode: 1);
  }

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<InstallResult> install(String apkPath) async => InstallResult.started;

  @override
  Future<String> cacheDir() async => Directory.systemTemp.path;
}

/// An update controller that finds no newer release (GitHub answers 404).
UpdateController fakeUpdates({AppInstaller? installer}) => UpdateController(
  service: UpdateService(
    client: MockClient((_) async => http.Response('', 404)),
    downloadsDir: () async => Directory.systemTemp,
  ),
  installer: installer ?? FakeInstaller(),
);
