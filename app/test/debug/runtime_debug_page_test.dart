import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:herald/debug/runtime_debug_page.dart';
import 'package:herald/runtime/runtime_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('herald/runtime');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RuntimeDebugPage(runtime: RuntimeChannel(channel)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows what the app has, then the check result', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'describe') {
        return {'prootExists': true, 'prootExecutable': true};
      }
      return {'ok': true, 'exitCode': 0, 'output': 'proot 5.1.107'};
    });
    await pumpPage(tester);

    expect(find.textContaining('prootExists: true'), findsOneWidget);
    expect(find.text('Not run yet.'), findsOneWidget);

    await tester.tap(find.text('Run proot --version'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OK (exit code 0)'), findsOneWidget);
    expect(find.textContaining('proot 5.1.107'), findsOneWidget);
  });

  testWidgets('a failed check shows FAILED and the reason', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'describe') return {};
      return {'ok': false, 'error': 'proot did not answer within 10 seconds'};
    });
    await pumpPage(tester);

    await tester.tap(find.text('Run proot --version'));
    await tester.pumpAndSettle();

    expect(find.textContaining('FAILED'), findsOneWidget);
    expect(find.textContaining('did not answer'), findsOneWidget);
  });

  testWidgets('a channel error is shown, not thrown', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'describe') return {};
      throw PlatformException(code: 'boom', message: 'native side failed');
    });
    await pumpPage(tester);

    await tester.tap(find.text('Run proot --version'));
    await tester.pumpAndSettle();

    expect(find.textContaining('FAILED'), findsOneWidget);
  });
}
