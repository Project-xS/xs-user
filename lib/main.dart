import 'package:xs_user/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/home_screen.dart';
import 'package:xs_user/login_screen.dart';
import 'package:xs_user/onboarding_screen.dart';
import 'package:xs_user/theme_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await GoogleSignIn.instance.initialize(serverClientId: dotenv.env['SERVER_CLIENT_ID']);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _getInitialScreen();
  }

  Future<void> _signOut(String reason) async {
    debugPrint('Forcing sign out because: $reason');
    await GoogleSignIn.instance.signOut();
    await Supabase.instance.client.auth.signOut();
  }

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    if (!hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginScreen();
    }

    final bool isSessionValid = await AuthService.isGoogleSessionValid();

    if (isSessionValid) {
      debugPrint('User session is valid. Proceeding to home screen.');
      return const HomeScreen();
    } else {
      await _signOut('Google session is no longer valid.');
      return const LoginScreen(snackbarMessage: "Your session has expired or access was revoked. Please sign in again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'XS User',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightBlue[48],
          foregroundColor: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.lightBlue[48],
        cardColor: Colors.grey[100],
        iconTheme: const IconThemeData(color: Colors.black54),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.lightBlue[48],
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor.withAlpha((255 * 0.5).round());
            }
            return Colors.grey.withAlpha((255 * 0.5).round());
          }),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark().copyWith(primary: const Color(0xFFFF6B35)),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF061224),
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF061224),
        cardColor: const Color(0xFF0D2130),
        iconTheme: const IconThemeData(color: Colors.grey),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF061224),
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: Colors.grey,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor;
            }
            return Colors.grey[700];
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor.withAlpha((255 * 0.5).round());
            }
            return Colors.grey[800];
          }),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _initialScreenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data ?? const LoginScreen();
          }
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}