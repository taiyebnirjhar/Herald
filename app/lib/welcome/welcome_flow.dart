import 'package:flutter/material.dart';

import '../runtime/runtime_channel.dart';
import '../setup/setup_page.dart';
import '../ui/herald_look.dart';
import 'welcome_store.dart';

/// Three screens shown on first launch only (WBS 5.1): what Herald is, the
/// one-time setup download, and the permissions it may ask for. The last
/// button saves that the welcome was seen, then opens the home screen.
class WelcomeFlow extends StatefulWidget {
  const WelcomeFlow({
    super.key,
    required this.welcome,
    required this.homeBuilder,
    this.runtime,
  });

  final WelcomeStore welcome;

  /// Builds the home screen that replaces the welcome flow.
  final WidgetBuilder homeBuilder;

  /// Used by the setup button. Defaults to the Android runtime channel.
  final RuntimeChannel? runtime;

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  static const _pageCount = 3;

  final _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pages.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.welcome.markSeen();
    } catch (_) {
      // Still open the home screen. The welcome may show once more next time.
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: widget.homeBuilder));
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupPage(runtime: widget.runtime ?? RuntimeChannel()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      body: HeraldBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  key: const ValueKey('welcome-pages'),
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    const _WelcomePage(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Welcome to Herald',
                      children: [
                        _Paragraph(
                          'Herald runs Hermes Agent, an AI assistant, right on '
                          'this phone.',
                        ),
                        _Paragraph(
                          'You do not need a computer or the Termux app. You '
                          'choose the AI service it talks to, and you can '
                          'change it later.',
                        ),
                      ],
                    ),
                    _WelcomePage(
                      icon: Icons.download_rounded,
                      title: 'Set up once, over Wi-Fi',
                      children: [
                        const _Paragraph(
                          'Herald downloads a small Linux base (about 52 MB) '
                          'and Hermes Agent. This happens once.',
                        ),
                        const _Paragraph(
                          'Use Wi-Fi for it, because the downloads are large. '
                          'Progress is shown while it runs.',
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HeraldLook.accent,
                              side: const BorderSide(color: HeraldLook.accent),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _openSetup,
                            child: const Text('Open setup'),
                          ),
                        ),
                      ],
                    ),
                    const _WelcomePage(
                      icon: Icons.verified_user_outlined,
                      title: 'Two permissions',
                      children: [
                        _Paragraph(
                          'Updates: Android asks you once to allow installs '
                          'from Herald. You can change this later in Android '
                          'settings.',
                        ),
                        _Paragraph(
                          'Notifications: the background service may need them '
                          'to show that the agent is running. Android may ask '
                          'you to allow them.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Dots(count: _pageCount, current: _page),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: _page == 0 ? null : _back,
                        style: TextButton.styleFrom(
                          foregroundColor: HeraldLook.muted,
                          minimumSize: const Size(88, 52),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: HeraldLook.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: HeraldLook.lavender,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _finishing ? null : _next,
                        child: Text(last ? 'Go to Herald' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  radius: 0.9,
                  colors: [
                    Colors.white,
                    Color(0xFFEDE6FF),
                    HeraldLook.accentSoft,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Icon(icon, size: 40, color: HeraldLook.accent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: HeraldLook.ink,
            ),
          ),
          const SizedBox(height: 20),
          HeraldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: HeraldLook.ink,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? HeraldLook.accent : HeraldLook.accentSoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
