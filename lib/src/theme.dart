import 'package:flutter/material.dart';

class AppTheme {
  static const darkBase = Color(0xFF0D1117);
  static const cardDark = Color(0xFF161B22);
  static const neuralTeal = Color(0xFF00D9FF);
  static const neuralBlue = Color(0xFF6366F1);
  static const neuralViolet = Color(0xFF9333EA);
  static const neonCyan = Color(0xFF00F0FF);
  static const neonPurple = Color(0xFFB794F6);

  static const neuralGradient = LinearGradient(
    colors: [neuralTeal, neuralBlue, neuralViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppTheme.darkBase,
    primaryColor: AppTheme.neuralBlue,
    useMaterial3: true,
  );
}
