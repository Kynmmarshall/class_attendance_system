import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient royalTwilight = LinearGradient(
    colors: [Color(0xFF0f172a), Color(0xFF312e81), Color(0xFF5b21b6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunriseBloom = LinearGradient(
    colors: [Color(0xFF1d976c), Color(0xFF2bc0e4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient emberGlow = LinearGradient(
    colors: [Color(0xFF8e24aa), Color(0xFFd81b60), Color(0xFFf06292)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppDecorations {
  static BoxDecoration glassCard({
    Color color = Colors.white,
    double opacity = .9,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      color: color.withValues(alpha: opacity),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 40,
          offset: Offset(0, 20),
        ),
      ],
    );
  }

  static BoxDecoration frostedPanel({double opacity = .85}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withValues(alpha: opacity),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 24,
          offset: Offset(0, 18),
        ),
      ],
    );
  }
}
