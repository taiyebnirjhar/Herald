import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';
import 'package:herald/update/app_installer.dart';
import 'package:herald/update/update_controller.dart';
import 'package:herald/update/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_key_value_store.dart';

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

/// GitHub's latest-release redirect pointing at [tag]; no release when null.
UpdateController _controller({String? tag}) => UpdateController(
      service: UpdateService(
        client: MockClient((_) async => tag == null
            ? http.Response('', 404)
            : http.Response('', 302, headers: {
                'location': 'https://github.com/taiyebnirjhar/Herald/releases/tag/$tag',
              })),
        downloadsDir: () async => Directory.systemTemp,
      ),
      installer: _NoopInstaller(),
    );

void main() {
  testWidgets('Hello screen shows the greeting and the update card', (tester) async {
    await tester.pumpWidget(HeraldApp(updates: _controller(), store: FakeKeyValueStore()));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Herald'), findsOneWidget);
    expect(find.text('Herald 0.1.0'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('a newer release shows Update now', (tester) async {
    await tester.pumpWidget(HeraldApp(updates: _controller(tag: 'v0.2.0'), store: FakeKeyValueStore()));
    await tester.pumpAndSettle();

    expect(find.text('Update now'), findsOneWidget);
    expect(find.textContaining('Version 0.2.0 is ready.'), findsOneWidget);
  });
}
