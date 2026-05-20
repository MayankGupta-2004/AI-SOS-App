import 'package:flutter/material.dart';

/// Kavach Design System — Color Palette
///
/// Centralized color definitions for consistent branding.
/// India-market optimized with safety-focused palette.

class KavachColors {
  KavachColors._();

  // ── Primary Colors ────────────────────────────────────────────
  static const Color saffron = Color(0xFFFF6B2B);
  static const Color saffronLight = Color(0xFFFF8A50);
  static const Color saffronDark = Color(0xFFE55A1B);
  static const Color crimson = Color(0xFFD32F2F);
  static const Color crimsonLight = Color(0xFFFF5252);
  static const Color crimsonDark = Color(0xFFB71C1C);
  static const Color forest = Color(0xFF2E7D32);
  static const Color forestLight = Color(0xFF43A047);
  static const Color forestDark = Color(0xFF1B5E20);
  static const Color mint = Color(0xFF43A047);

  // ── Surface Colors (Light) ────────────────────────────────────
  static const Color cream = Color(0xFFFFF8F0);
  static const Color creamDark = Color(0xFFF5EDE0);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFBF7);

  // ── Surface Colors (Dark) ─────────────────────────────────────
  static const Color darkBg = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF1A1A24);
  static const Color darkCard = Color(0xFF22222E);
  static const Color darkElevated = Color(0xFF2A2A38);

  // ── Text Colors ───────────────────────────────────────────────
  static const Color ink = Color(0xFF1C1B20);
  static const Color inkLight = Color(0xFF2D2B35);
  static const Color slate = Color(0xFF6B6880);
  static const Color slateMuted = Color(0xFF9995A8);
  static const Color textOnDark = Color(0xFFF5F2FA);
  static const Color textOnDarkMuted = Color(0xFF9B98A8);

  // ── Accent / Semantic ─────────────────────────────────────────
  static const Color divider = Color(0xFFEDE8E0);
  static const Color dividerDark = Color(0xFF2E2E3A);
  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color warning = Color(0xFFF9A825);
  static const Color warningBg = Color(0xFFFFF8E1);
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorBg = Color(0xFFFFEBEE);

  // ── Gradient Presets ──────────────────────────────────────────
  static const LinearGradient saffronGradient = LinearGradient(
    colors: [saffron, saffronLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient crimsonGradient = LinearGradient(
    colors: [Color(0xFFFF5252), crimson, Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient forestGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), forest, Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF15151F), Color(0xFF0D0D12)],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF5EC), cream],
    stops: [0.0, 0.45],
  );

  static const LinearGradient protectedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0FFF0), cream],
    stops: [0.0, 0.45],
  );

  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF0F0), cream],
    stops: [0.0, 0.45],
  );

  // ── Glass Morphism ────────────────────────────────────────────
  static Color glassLight = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.25);
  static Color glassDark = Colors.white.withValues(alpha: 0.08);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.12);
}
