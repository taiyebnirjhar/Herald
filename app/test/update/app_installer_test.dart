import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/update/app_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('herald/app_update');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('installedVersion reads name and code', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'installedVersion');
      return {'versionName': '0.1.3', 'versionCode': 300};
    });
    final v = await MethodChannelAppInstaller(channel).installedVersion();
    expect(v.versionName, '0.1.3');
    expect(v.versionCode, 300);
  });

  test('installedVersion falls back when Android gives nothing', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final v = await MethodChannelAppInstaller(channel).installedVersion();
    expect(v.versionName, '0.0.0');
    expect(v.versionCode, 0);
  });

  test('canInstall reads the permission state', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    expect(await MethodChannelAppInstaller(channel).canInstall(), isFalse);
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    expect(await MethodChannelAppInstaller(channel).canInstall(), isTrue);
  });

  test('install sends the path and reports started', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'install');
      expect(call.arguments, {'path': '/cache/updates/herald-0.1.3.apk'});
      return 'started';
    });
    final result = await MethodChannelAppInstaller(channel)
        .install('/cache/updates/herald-0.1.3.apk');
    expect(result, InstallResult.started);
  });

  test('install reports the permission step', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'needs_permission');
    final result = await MethodChannelAppInstaller(channel).install('/x.apk');
    expect(result, InstallResult.needsPermission);
  });

  test('cacheDir throws when Android gives no folder', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(MethodChannelAppInstaller(channel).cacheDir(), throwsStateError);
  });

  test('a platform error reaches the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'bad_args', message: 'No file given');
    });
    expect(
      MethodChannelAppInstaller(channel).install(''),
      throwsA(isA<PlatformException>()),
    );
  });
}
