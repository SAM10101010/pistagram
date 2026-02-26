import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const PistagramApp());
}

class PistagramApp extends StatefulWidget {
  const PistagramApp({super.key});

  @override
  State<PistagramApp> createState() => _PistagramAppState();

  static _PistagramAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_PistagramAppState>();
  }
}

class _PistagramAppState extends State<PistagramApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  ThemeProvider get themeProvider => _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _themeProvider.accentColor;
    final accentSec = _themeProvider.accentSecondary;
    return MaterialApp(
      title: 'Pistagram',
      debugShowCheckedModeBanner: false,
      themeMode: _themeProvider.themeMode,
      theme: _buildLightTheme(accent, accentSec),
      darkTheme: _buildDarkTheme(accent, accentSec),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildDarkTheme(Color accent, Color secondary) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: secondary,
        surface: const Color(0xFF1A1A2E),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D0D),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      useMaterial3: true,
    );
  }

  ThemeData _buildLightTheme(Color accent, Color secondary) {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: secondary,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      useMaterial3: true,
    );
  }
}
