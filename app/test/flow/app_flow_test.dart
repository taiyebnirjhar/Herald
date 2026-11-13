import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/main.dart';
import 'package:herald/update/app_installer.dart';
import 'package:herald/update/update_controller.dart';
import 'package:herald/update/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_key_value_store.dart';

/// One user journey through the whole app, with the Android side and GitHub
/// faked: start, see the Hello screen, check for an update, open the runtime
/// check from the menu, run it, go back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const updateChannel = MethodChannel('herald/app_update');
  const runtimeChannel = MethodChannel('herald/runtime');

  final apk = utf8.encode('flow apk');
  final sha = sha256.convert(apk).toString();

  setUp(() {
    messenger.setMockMethodCallHandler(updateChannel, (call) async {
      switch (call.method) {
        case 'installedVersion':
          return {'versionName': '0.1.3', 'versionCode': 300};
        case 'cacheDir':
          return Directory.systemTemp.path;
        case 'canInstall':
          return true;
        default:
          return 'started';
      }
    });
    messenger.setMockMethodCallHandler(runtimeChannel, (call) async {
      if (call.method == 'describe') return {'prootExists': true};
      return {'ok': true, 'exitCode': 0, 'output': 'proot 5.1.107'};
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(updateChannel, null);
    messenger.setMockMethodCallHandler(runtimeChannel, null);
  });

  testWidgets('start, check for updates, open setup, go back',
      (tester) async {
    final updates = UpdateController(
      service: UpdateService(
        client: MockClient((r) async {
          if (r.url.path == '/taiyebnirjhar/Herald/releases/latest') {
            return http.Response('', 302, headers: {
              'location': 'https://github.com/taiyebnirjhar/Herald/releases/tag/v0.1.3',
            });
          }
          if (r.url.path.endsWith('.sha256')) {
            return http.Response('$sha  x\n', 200);
          }
          return http.Response.bytes(apk, 200);
        }),
        downloadsDir: () async => Directory.systemTemp,
      ),
      installer: MethodChannelAppInstaller(updateChannel),
    );

    await tester.pumpWidget(HeraldApp(updates: updates, store: FakeKeyValueStore()));
    await tester.pumpAndSettle();

    // First screen: greeting, installed version, and the update check ran.
    expect(find.text('Hello, Herald'), findsOneWidget);
    expect(find.text('Herald 0.1.3'), findsOneWidget);
    expect(find.text('You have the newest version.'), findsOneWidget);

    // Manual check works from the card.
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('You have the newest version.'), findsOneWidget);

    // Menu opens the setup screen with its steps.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Set up Herald'), findsOneWidget);
    expect(find.text('1. Linux base'), findsOneWidget);
    expect(find.text('2. Hermes Agent'), findsOneWidget);

    // Back to the first screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Hello, Herald'), findsOneWidget);
  });
}
