import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/runtime/runtime_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('herald/runtime');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('describe passes the Android facts through', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'describe');
      return {'prootExists': true, 'prootExecutable': true, 'loaderExists': false};
    });
    final facts = await RuntimeChannel().describe();
    expect(facts['prootExists'], isTrue);
    expect(facts['loaderExists'], isFalse);
  });

  test('describe with no answer gives an empty map, not an error', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await RuntimeChannel().describe(), isEmpty);
  });

  test('prootVersion reads a successful check', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'prootVersion');
      return {'ok': true, 'exitCode': 0, 'output': 'proot 5.1.107'};
    });
    final check = await RuntimeChannel().prootVersion();
    expect(check.ok, isTrue);
    expect(check.exitCode, 0);
    expect(check.output, 'proot 5.1.107');
    expect(check.error, isNull);
  });

  test('prootVersion reads a failed check with its error', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
          'ok': false,
          'error': 'libproot.so is missing from the app',
        });
    final check = await RuntimeChannel().prootVersion();
    expect(check.ok, isFalse);
    expect(check.error, contains('missing'));
    expect(check.output, '');
  });

  test('a missing answer counts as a failed check', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final check = await RuntimeChannel().prootVersion();
    expect(check.ok, isFalse);
  });

  test('installRootfs asks Android to unpack the bundled image', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'installRootfs');
      expect(call.arguments, {'path': '/cache/linux.tar.gz'});
      return {'ok': true, 'path': '/data/runtime/debian'};
    });
    final r = await RuntimeChannel().installRootfs(path: '/cache/linux.tar.gz');
    expect(r.ok, isTrue);
  });

  test('progress from Android reaches onProgress', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final rc = RuntimeChannel();
    String? stage;
    double? fraction;
    rc.onProgress = (s, f) {
      stage = s;
      fraction = f;
    };
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('progress', {'stage': 'Unpacking the Linux image', 'fraction': 0.5}),
      ),
      (_) {},
    );
    expect(stage, 'Unpacking the Linux image');
    expect(fraction, 0.5);
  });

  test('installRootfs shows the reason when the checksum fails', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
          'ok': false,
          'error': "The Linux image didn't pass the safety check",
        });
    final r = await RuntimeChannel().installRootfs(path: 'x');
    expect(r.ok, isFalse);
    expect(r.error, contains('safety check'));
  });

  test('runUname reads the output', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runUname');
      return {'ok': true, 'exitCode': 0, 'output': 'Linux herald 6.1 aarch64 GNU/Linux'};
    });
    final r = await RuntimeChannel().runUname();
    expect(r.output, contains('aarch64'));
  });

  test('hermesStatus reads running and the log', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hermesStatus');
      return {'running': true, 'log': 'step 3 of 9'};
    });
    final status = await RuntimeChannel().hermesStatus();
    expect(status.running, isTrue);
    expect(status.log, 'step 3 of 9');
    expect(status.result, isNull);
  });

  test('hermesStatus carries the result when the install is done', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
          'running': false,
          'log': 'done',
          'result': {'ok': true, 'output': 'Hermes Agent v2026.9.24'},
        });
    final status = await RuntimeChannel().hermesStatus();
    expect(status.running, isFalse);
    expect(status.result?.ok, isTrue);
    expect(status.result?.output, contains('v2026.9.24'));
  });

  test('hermesInstall starts it with the downloaded script', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hermesInstall');
      expect(call.arguments, {'script': '/files/hermes-install.sh'});
      return {'started': true};
    });
    await RuntimeChannel().hermesInstall(script: '/files/hermes-install.sh');
  });

  test('hermesHealth reads the phase and message', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hermesHealth');
      return {'phase': 'READY', 'message': 'Hermes is running.'};
    });
    final h = await RuntimeChannel().hermesHealth();
    expect(h.phase, 'READY');
    expect(h.message, 'Hermes is running.');
  });

  test('startHermes and stopHermes call the matching native action', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {};
    });
    await RuntimeChannel().startHermes();
    await RuntimeChannel().stopHermes();
    expect(calls, ['startHermes', 'stopHermes']);
  });
}
