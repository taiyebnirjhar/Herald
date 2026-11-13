import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/chat_load_tracker.dart';

void main() {
  group('Hermes address', () {
    test('the chat opens the loopback web UI on port 9119', () {
      expect(hermesUri.toString(), 'http://127.0.0.1:9119/');
    });

    test('pages on Hermes own address are allowed', () {
      expect(isHermesUri(Uri.parse('http://127.0.0.1:9119/')), isTrue);
      expect(isHermesUri(Uri.parse('http://127.0.0.1:9119/chat?x=1')), isTrue);
    });

    test('other hosts, ports and schemes are not Hermes', () {
      expect(isHermesUri(Uri.parse('https://127.0.0.1:9119/')), isFalse);
      expect(isHermesUri(Uri.parse('http://localhost:9119/')), isFalse);
      expect(isHermesUri(Uri.parse('http://0.0.0.0:9119/')), isFalse);
      expect(isHermesUri(Uri.parse('http://127.0.0.1:8080/')), isFalse);
      expect(isHermesUri(Uri.parse('http://127.0.0.1/')), isFalse);
      expect(isHermesUri(Uri.parse('https://example.com/')), isFalse);
      expect(isHermesUri(Uri.parse('about:blank')), isFalse);
      expect(isHermesUri(Uri.parse('data:text/html,hi')), isFalse);
    });
  });

  group('ChatLoadTracker', () {
    test('starts with the spinner and no banner', () {
      final t = ChatLoadTracker();
      expect(t.phase, ChatPhase.loading);
      expect(t.showSpinner, isTrue);
      expect(t.showOfflineBanner, isFalse);
      expect(t.hasLoadedOnce, isFalse);
    });

    test('the spinner goes away when the first page finishes', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..pageFinished();
      expect(t.phase, ChatPhase.ready);
      expect(t.showSpinner, isFalse);
      expect(t.showOfflineBanner, isFalse);
      expect(t.hasLoadedOnce, isTrue);
    });

    test('a page that cannot load shows the offline banner, not the spinner', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..resourceError(isForMainFrame: true);
      expect(t.phase, ChatPhase.offline);
      expect(t.showOfflineBanner, isTrue);
      expect(t.showSpinner, isFalse);
    });

    test('the error page that follows a failed load keeps the banner', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..resourceError(isForMainFrame: true)
        ..pageFinished();
      expect(t.phase, ChatPhase.offline);
      expect(t.showOfflineBanner, isTrue);
      expect(t.hasLoadedOnce, isFalse);
    });

    test('a page starting again while offline does not hide the banner', () {
      final t = ChatLoadTracker()
        ..resourceError(isForMainFrame: true)
        ..pageStarted();
      expect(t.showOfflineBanner, isTrue);
    });

    test('Retry clears the banner and shows loading until the page finishes', () {
      final t = ChatLoadTracker()
        ..resourceError(isForMainFrame: true)
        ..retry();
      expect(t.showOfflineBanner, isFalse);
      expect(t.showSpinner, isTrue);

      t
        ..pageStarted()
        ..pageFinished();
      expect(t.phase, ChatPhase.ready);
      expect(t.showSpinner, isFalse);
    });

    test('a failed Retry shows the banner again', () {
      final t = ChatLoadTracker()
        ..resourceError(isForMainFrame: true)
        ..retry()
        ..pageStarted()
        ..resourceError(isForMainFrame: true)
        ..pageFinished();
      expect(t.showOfflineBanner, isTrue);
    });

    test('a failed image or script does not show the banner', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..resourceError(isForMainFrame: false)
        ..pageFinished();
      expect(t.phase, ChatPhase.ready);
      expect(t.showOfflineBanner, isFalse);
    });

    test('an error with an unknown frame is treated as the page', () {
      final t = ChatLoadTracker()..resourceError(isForMainFrame: null);
      expect(t.showOfflineBanner, isTrue);
    });

    test('after the first load, a later navigation does not show the spinner', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..pageFinished()
        ..pageStarted();
      expect(t.phase, ChatPhase.loading);
      expect(t.showSpinner, isFalse);
      expect(t.hasLoadedOnce, isTrue);
    });

    test('a failure after a good load shows the banner', () {
      final t = ChatLoadTracker()
        ..pageStarted()
        ..pageFinished()
        ..pageStarted()
        ..resourceError(isForMainFrame: true)
        ..pageFinished();
      expect(t.showOfflineBanner, isTrue);
      expect(t.showSpinner, isFalse);
    });
  });
}
