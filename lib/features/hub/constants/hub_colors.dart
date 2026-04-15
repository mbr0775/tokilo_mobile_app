// lib/features/hub/constants/hub_colors.dart
//
// All DarkSlateBlue (#483D8B) color constants and gradients
// used across every Tokilo Business Hub component.

import 'package:flutter/material.dart';

class HubColors {
  HubColors._();

  // ── Base palette ──────────────────────────────────────────────
  static const Color primary     = Color(0xFF483D8B); // DarkSlateBlue
  static const Color primaryDk   = Color(0xFF2A2060);
  static const Color primaryLt   = Color(0xFF6B5FBD);
  static const Color violet      = Color(0xFF7C6FCD);
  static const Color accentRed   = Color(0xFFF82727); // spec: 248,39,39
  static const Color accentCoral = Color(0xFFFF6B6B);
  static const Color gold        = Color(0xFFFFB940);
  static const Color goldDk      = Color(0xFFFF8C42);
  static const Color success     = Color(0xFF22C55E);
  static const Color white       = Colors.white;

  // ── Surface / background ──────────────────────────────────────
  static const Color background  = Color(0xFFF6F5FF);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color border      = Color(0xFFE4E0F5);

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1C1640);
  static const Color textSec     = Color(0xFF6B658E);
  static const Color textHint    = Color(0xFFAEA9C8);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient heroGrad = LinearGradient(
    colors: [Color(0xFF2A2060), Color(0xFF483D8B), Color(0xFF6B5FBD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGrad = LinearGradient(
    colors: [Color(0xFF483D8B), Color(0xFF6B5FBD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGrad = LinearGradient(
    colors: [Color(0xFFF82727), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGrad = LinearGradient(
    colors: [Color(0xFFFFB940), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGrad = LinearGradient(
    colors: [Color(0xFF7C6FCD), Color(0xFFAB9FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}