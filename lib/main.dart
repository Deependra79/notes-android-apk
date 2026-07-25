import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';
import 'screens/home_navigation_screen.dart';
import 'screens/passcode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-initialize database on startup (Native only)
  if (!kIsWeb) {
    await DatabaseHelper.instance.database;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Local Notes',
          debugShowCheckedModeBanner: false,
          
          // Light Theme Design - Chill Sage / Emerald Green & Gold
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF10B981), // Emerald
              brightness: Brightness.light,
              primary: const Color(0xFF047857), // Deep Forest Green
              secondary: const Color(0xFFD97706), // Warm Gold
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
            scaffoldBackgroundColor: const Color(0xFFF4FAF6), // Chill mint cream
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
            ),
          ),

          // Dark Theme Design - Pitch Black, Charcoal Grey, and Silver
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF3F4F6), // Platinum Silver
              secondary: Color(0xFF9CA3AF), // Medium Grey
              surface: Color(0xFF1C1917), // Charcoal Grey (Stone 900)
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            scaffoldBackgroundColor: const Color(0xFF000000), // Pitch Black
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
            ),
          ),
          
          themeMode: currentMode, // Listens to global Day/Night setting
          home: const AppLaunchGuard(),
        );
      },
    );
  }
}

class AppLaunchGuard extends StatefulWidget {
  const AppLaunchGuard({super.key});

  @override
  State<AppLaunchGuard> createState() => _AppLaunchGuardState();
}

class _AppLaunchGuardState extends State<AppLaunchGuard> {
  bool _isUnlocked = false;
  bool _checkingPasscode = true;

  @override
  void initState() {
    super.initState();
    _checkPasscodeStatus();
  }

  Future<void> _checkPasscodeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPasscode = prefs.getString('app_passcode') != null;
    setState(() {
      _isUnlocked = !hasPasscode;
      _checkingPasscode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPasscode) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isUnlocked) {
      return const HomeNavigationScreen();
    }

    return PasscodeScreen(
      mode: PasscodeMode.verify,
      onSuccess: () {
        setState(() {
          _isUnlocked = true;
        });
      },
    );
  }
}
