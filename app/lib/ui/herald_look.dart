import 'package:flutter/material.dart';

/// Colours and shared pieces for the light, glassy look (WBS 5.1 and 5.6).
/// The same values as the Hello screen in main.dart.
class HeraldLook {
  const HeraldLook._();

  static const ink = Color(0xFF17151F);
  static const muted = Color(0xFF7A7785);
  static const accent = Color(0xFF8B4DFF);
  static const accentSoft = Color(0xFFC9B6FF);
  static const lavender = Color(0xFFD9CCFF);
  static const lime = Color(0xFFE4F7C4);
  static const card = Color(0xE6FFFFFF);
}

/// The lavender-to-lime gradient behind every screen.
class HeraldBackground extends StatelessWidget {
  const HeraldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [HeraldLook.lavender, Colors.white, HeraldLook.lime],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A white, rounded, slightly see-through card.
class HeraldCard extends StatelessWidget {
  const HeraldCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HeraldLook.card,
        borderRadius: BorderRadius.circular(24),
      ),
      // Material here lets ListTile and Switch paint their ink on the card.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
