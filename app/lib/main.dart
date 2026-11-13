import 'package:flutter/material.dart';

void main() {
  runApp(const HeraldApp());
}

/// Palette taken from the light, glassy chat-bot UI reference (lavender + lime).
class HeraldColors {
  static const ink = Color(0xFF17151F);
  static const muted = Color(0xFF7A7785);
  static const accent = Color(0xFF8B4DFF);
  static const accentSoft = Color(0xFFC9B6FF);
  static const lavender = Color(0xFFD9CCFF);
  static const lime = Color(0xFFE4F7C4);
  static const card = Color(0xE6FFFFFF);
}

class HeraldApp extends StatelessWidget {
  const HeraldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herald',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HeraldColors.accent,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HelloPage(),
    );
  }
}

class HelloPage extends StatelessWidget {
  const HelloPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          // Scrolls on short screens; fills the screen on tall ones.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 16),
                      const _Orb(),
                      const SizedBox(height: 16),
                      const Text(
                        'Hello, Herald',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: HeraldColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your AI agent, running on this phone.\nSetup comes next.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: HeraldColors.muted,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      const _StatusCard(),
                      const SizedBox(height: 16),
                      const _BottomBar(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        _RoundIconButton(
          icon: Icons.menu_rounded,
          tooltip: 'Menu',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menu comes in a later phase.')),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
        elevation: 0,
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

/// Decorative glossy orb in the spirit of the reference UI (no image asset needed).
class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [
            Colors.white,
            Color(0xFFEDE6FF),
            HeraldColors.accentSoft,
            Color(0xFFBDE9FF),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: HeraldColors.accent.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HeraldColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phase 0 · Hello build',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HeraldColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This APK came from GitHub Actions and installed on your phone.',
            style: TextStyle(fontSize: 14, height: 1.4, color: HeraldColors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HeraldColors.accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hello from Herald. The app runs.'),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating pill nav, decorative in Phase 0.
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavIcon(icon: Icons.home_rounded, selected: true),
          _NavIcon(icon: Icons.chat_bubble_outline_rounded),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HeraldColors.accent,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          _NavIcon(icon: Icons.tune_rounded),
          _NavIcon(icon: Icons.settings_outlined),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? HeraldColors.accent : Colors.transparent,
      ),
      child: Icon(
        icon,
        color: selected ? Colors.white : HeraldColors.muted,
      ),
    );
  }
}
