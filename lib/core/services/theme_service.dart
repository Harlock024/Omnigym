import 'package:flutter/material.dart';
import '../models/tenant.dart';

class ThemeService {
  const ThemeService._();

  static ThemeData fromSettings(TenantSettings settings) {
    final primary = _parseColor(settings.primaryColor) ?? const Color(0xFF1976D2);
    final accent = _parseColor(settings.accentColor) ?? const Color(0xFFFF6F00);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: accent,
      ),
    );
  }

  static ThemeData get defaultTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      );

  static Color? _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.parse(
        cleaned.length == 6 ? 'FF$cleaned' : cleaned,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return null;
    }
  }
}
