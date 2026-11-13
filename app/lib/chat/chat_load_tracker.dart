/// Pure Dart rules for the chat WebView: where Hermes's web UI lives, which
/// pages the WebView may open, and when to show the spinner or the offline
/// banner. No Flutter imports, so it is unit tested without a device.
library;

/// Hermes's web UI. Hermes listens on loopback only (PLAN.md D7).
const String hermesHost = '127.0.0.1';
const int hermesPort = 9119;

/// The address the chat screen opens.
final Uri hermesUri = Uri(
  scheme: 'http',
  host: hermesHost,
  port: hermesPort,
  path: '/',
);

/// True for pages on Hermes's own address. The chat WebView opens nothing else
/// as a page, so a link to another site cannot replace the chat.
bool isHermesUri(Uri uri) =>
    uri.scheme == 'http' && uri.host == hermesHost && uri.port == hermesPort;

enum ChatPhase { loading, ready, offline }

/// Decides what the chat screen shows, from the WebView's load events.
///
/// Events arrive in this order on Android: page started, then (on failure) an
/// error, then page finished. An error must stay "offline" even though the
/// WebView still reports "finished" for its own error page.
class ChatLoadTracker {
  ChatPhase _phase = ChatPhase.loading;
  bool _loadedOnce = false;

  ChatPhase get phase => _phase;

  /// True once a page has loaded successfully at least once.
  bool get hasLoadedOnce => _loadedOnce;

  /// The full-screen spinner: only until the first page loads.
  bool get showSpinner => _phase == ChatPhase.loading && !_loadedOnce;

  /// The "can't reach Hermes" banner with a Retry button.
  bool get showOfflineBanner => _phase == ChatPhase.offline;

  /// A page started loading. Does not clear an offline state; only [retry] does.
  void pageStarted() {
    if (_phase != ChatPhase.offline) _phase = ChatPhase.loading;
  }

  /// A page finished loading. Stays offline if the page is the error page.
  void pageFinished() {
    if (_phase == ChatPhase.offline) return;
    _phase = ChatPhase.ready;
    _loadedOnce = true;
  }

  /// A resource failed. Only failures of the main page count; a missing image
  /// or script does not show the banner. An unknown source counts as the page.
  void resourceError({required bool? isForMainFrame}) {
    if (isForMainFrame == false) return;
    _phase = ChatPhase.offline;
  }

  /// The user tapped Retry: back to loading until the next page finishes.
  void retry() {
    _phase = ChatPhase.loading;
  }
}
