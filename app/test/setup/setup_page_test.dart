import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/runtime/runtime_channel.dart';
import 'package:herald/setup/setup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('herald/runtime');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> pump(WidgetTester tester, Map<String, dynamic> facts) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'describe':
          return facts;
        case 'hermesStatus':
          return {'running': false, 'log': ''};
        default:
          return {'ok': true, 'output': ''};
      }
    });
    await tester.pumpWidget(MaterialApp(home: SetupPage(runtime: RuntimeChannel(channel))));
    await tester.pumpAndSettle();
  }

  test('plainLog removes terminal colour codes', () {
    expect(plainLog('\u001b[0;32mDetected\u001b[0m linux'), 'Detected linux');
    expect(plainLog('\uFFFD[0;36m→\uFFFD[0m Install'), '→ Install');
    expect(plainLog('no codes here'), 'no codes here');
  });

  testWidgets('a new install shows the two steps, with the first one ready to start', (tester) async {
    await pump(tester, {'linuxInstalled': false});

    expect(find.text('Set up Herald'), findsOneWidget);
    expect(find.text('1. Linux base'), findsOneWidget);
    expect(find.text('2. Hermes Agent'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);
    expect(find.text('Set up the Linux base first.'), findsOneWidget);
  });

  testWidgets('with the Linux base already installed, Hermes can be installed', (tester) async {
    await pump(tester, {'linuxInstalled': true});

    expect(find.text('Ready.'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('technical details are hidden until asked for', (tester) async {
    await pump(tester, {'linuxInstalled': false, 'prootExists': true});

    expect(find.textContaining('prootExists'), findsNothing);
    await tester.tap(find.text('Show technical details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('prootExists: true'), findsOneWidget);
    expect(find.text('Run proot --version'), findsOneWidget);
  });

  test('the free-space rule names the space needed and the space free', () {
    expect(spaceProblem(100, linuxNeedMb, 'the Linux base'), isNotNull);
    expect(spaceProblem(100, linuxNeedMb, 'the Linux base'), contains('100 MB free'));
    expect(spaceProblem(linuxNeedMb, linuxNeedMb, 'the Linux base'), isNull);
    expect(spaceProblem(null, linuxNeedMb, 'the Linux base'), isNull);
  });
}
