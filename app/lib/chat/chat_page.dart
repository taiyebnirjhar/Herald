import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart' show HeraldColors;
import 'chat_load_tracker.dart';

/// The v1 chat: Hermes's own web UI (PLAN.md D5), shown in a WebView inside
/// the Herald look. Hermes runs on this phone at 127.0.0.1:9119.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _tracker = ChatLoadTracker();
  late final WebViewController _web;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Pages open only on Hermes's own address. Other sites are blocked.
          onNavigationRequest: (request) =>
              !request.isMainFrame || isHermesUri(Uri.parse(request.url))
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent,
          onPageStarted: (_) => _update(_tracker.pageStarted),
          onPageFinished: (_) => _update(_tracker.pageFinished),
          onWebResourceError: (error) => _update(
            () => _tracker.resourceError(isForMainFrame: error.isForMainFrame),
          ),
        ),
      )
      ..loadRequest(hermesUri);
  }

  void _update(void Function() change) {
    if (mounted) setState(change);
  }

  /// Back goes to the previous page inside the chat first, then leaves it.
  Future<void> _goBackOrLeave() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _retry() {
    setState(_tracker.retry);
    _web.loadRequest(hermesUri);
  }

  @override
  Widget build(BuildContext context) {
    final offline = _tracker.showOfflineBanner;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackOrLeave();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [HeraldColors.lavender, Colors.white, HeraldColors.lime],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _ChatTopBar(onBack: _goBackOrLeave),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: Stack(
                          children: [
                            // Kept in the tree while offline, so it is not reloaded
                            // from scratch on Retry.
                            Offstage(
                              offstage: offline,
                              child: WebViewWidget(controller: _web),
                            ),
                            if (_tracker.showSpinner)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: HeraldColors.accent,
                                ),
                              ),
                            if (offline) _OfflineBanner(onRetry: _retry),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'Chat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HeraldColors.ink,
              ),
            ),
          ),
          // Same width as the back button, so the title stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 48 px circle: meets the 44 px minimum touch target.
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: HeraldColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Shown over the blank chat area when Hermes cannot be reached.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HeraldColors.lavender),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: HeraldColors.accent,
            ),
            const SizedBox(height: 12),
            const Text(
              "Can't reach Hermes",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HeraldColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hermes is not answering on this phone yet. Wait a moment, then tap Retry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: HeraldColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: HeraldColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
