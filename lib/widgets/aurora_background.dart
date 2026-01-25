import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0f172a), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: _blurredOrb(
              size: 220,
              colors: [Color(0xFF22d3ee).withValues(alpha: .6), Colors.transparent],
            ),
          ),
          Positioned(
            bottom: -140,
            right: -40,
            child: _blurredOrb(
              size: 260,
              colors: [Color(0xFFa855f7).withValues(alpha: .5), Colors.transparent],
            ),
          ),
          Positioned(
            top: 120,
            right: -100,
            child: Transform.rotate(
              angle: math.pi / 6,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: .08),
                      Colors.white.withValues(alpha: .02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blurredOrb({required double size, required List<Color> colors}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
