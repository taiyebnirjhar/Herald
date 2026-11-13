import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/provider_page.dart';

class _FakeSaver implements ProviderSaver {
  _FakeSaver({this.problem});
  final String? problem;
  final calls = <Map<String, String>>[];

  @override
  Future<String?> save({required String provider, required String key, required String model}) async {
    calls.add({'provider': provider, 'key': key, 'model': model});
    return problem;
  }
}

Future<void> _open(WidgetTester tester, ProviderSaver saver) async {
  await tester.pumpWidget(MaterialApp(home: ProviderPage(saver: saver)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

void main() {
  testWidgets('shows the three providers, with OpenRouter and its model filled in', (tester) async {
    await _open(tester, _FakeSaver());

    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('xAI (Grok)'), findsOneWidget);
    expect(_text(tester, 1), 'openrouter/auto');
  });

  testWidgets('picking a provider fills in its starting model', (tester) async {
    await _open(tester, _FakeSaver());

    await tester.tap(find.text('Google Gemini'));
    await tester.pumpAndSettle();

    expect(_text(tester, 1), 'gemini-2.5-flash');
  });

  testWidgets('saving sends the provider, key and model, says so, and clears the key', (tester) async {
    final saver = _FakeSaver();
    await _open(tester, saver);

    await tester.tap(find.text('xAI (Grok)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'xai-test-0123456789');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saver.calls, [
      {'provider': 'xai', 'key': 'xai-test-0123456789', 'model': 'grok-4'},
    ]);
    expect(find.textContaining('Hermes will use xAI (Grok) with grok-4.'), findsOneWidget);
    expect(_text(tester, 0), '');
  });

  testWidgets('a failed save shows the message and keeps the key so it can be fixed', (tester) async {
    await _open(
      tester,
      _FakeSaver(problem: "Couldn't save the key. Make sure Hermes is set up on the Home screen."),
    );

    await tester.enterText(find.byType(TextField).at(0), 'sk-or-v1-0123456789');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't save the key"), findsOneWidget);
    expect(_text(tester, 0), 'sk-or-v1-0123456789');
  });
}
