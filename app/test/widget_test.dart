import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';
import 'package:herald/update/app_installer.dart';
import 'package:herald/update/update_controller.dart';
import 'package:herald/update/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NoopInstaller implements AppInstaller {
  @override
  Future<InstalledVersion> installedVersion() async =>
      const InstalledVersion(versionName: '0.1.0', versionCode: 1);
  @override
  Future<bool> canInstall() async => true;
  @override
  Future<InstallResult> install(String apkPath) async => InstallResult.started;
  @override
  Future<String> cacheDir() async => Directory.systemTemp.path;
}

UpdateController _controller() => UpdateController(
      service: UpdateService(
        // No release yet: the check is quiet and the screen says "newest".
        client: MockClient((_) async => http.Response('', 404)),
        downloadsDir: () async => Directory.systemTemp,
      ),
      installer: _NoopInstaller(),
    );

void main() {
  testWidgets('Hello screen shows the greeting and the update card', (tester) async {
    await tester.pumpWidget(HeraldApp(updates: _controller()));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Herald'), findsOneWidget);
    expect(find.text('Herald 0.1.0'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('a newer release shows Update now', (tester) async {
    final controller = UpdateController(
      service: UpdateService(
        client: MockClient((_) async => http.Response(jsonEncode({
              'tag_name': 'v0.2.0',
              'body': 'New',
              'assets': [
                {
                  'name': 'herald-0.2.0-arm64.apk',
                  'size': 3,
                  'digest': 'sha256:${'a' * 64}',
                  'browser_download_url':
                      'https://github.com/taiyebnirjhar/Herald/releases/download/v0.2.0/herald-0.2.0-arm64.apk',
                },
              ],
            }), 200)),
        downloadsDir: () async => Directory.systemTemp,
      ),
      installer: _NoopInstaller(),
    );
    await tester.pumpWidget(HeraldApp(updates: controller));
    await tester.pumpAndSettle();

    expect(find.text('Update now'), findsOneWidget);
    expect(find.textContaining('Version 0.2.0 is ready.'), findsOneWidget);
  });
}
