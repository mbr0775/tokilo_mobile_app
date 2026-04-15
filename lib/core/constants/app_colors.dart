import 'package:flutter/material.dart';

class AppColors {
  // ✅ Tokilo Brand Primary Color #06768D
  static const Color primary = Color(0xFF06768D);
  static const Color primaryDark = Color(0xFF045A6B);
  static const Color primaryLight = Color(0xFF0899B0);
  static const Color accent = Color(0xFF00C9B1);

  // Background Colors
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Border & Divider
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF06768D), Color(0xFF00C9B1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF03404E), Color(0xFF06768D), Color(0xFF00C9B1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}