import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _accentKey = 'accent_color';

  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFFDD2A7B); // Pink default

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  Color get accentColor => _accentColor;

  // Predefined accent color options
  static const List<Color> accentOptions = [
    Color(0xFFDD2A7B), // Pink (default)
    Color(0xFF8134AF), // Purple
    Color(0xFF1DA1F2), // Blue
    Color(0xFF00C853), // Green
    Color(0xFFF58529), // Orange
    Color(0xFFE53935), // Red
    Color(0xFFFFD600), // Yellow
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF6F00), // Amber
    Color(0xFF7C4DFF), // Deep Purple
  ];

  static const List<String> accentNames = [
    'Hot Pink',
    'Purple',
    'Blue',
    'Green',
    'Orange',
    'Red',
    'Yellow',
    'Cyan',
    'Amber',
    'Deep Purple',
  ];

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final colorValue = prefs.getInt(_accentKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.value);
    notifyListeners();
  }

  // Gradient using accent color
  LinearGradient get accentGradient => LinearGradient(
        colors: [
          _accentColor,
          HSLColor.fromColor(_accentColor)
              .withHue((HSLColor.fromColor(_accentColor).hue + 40) % 360)
              .toColor(),
        ],
      );

  // Secondary color derived from accent
  Color get accentSecondary =>
      HSLColor.fromColor(_accentColor)
          .withHue((HSLColor.fromColor(_accentColor).hue + 40) % 360)
          .toColor();
}
