import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/home_screen.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/onboarding_screen.dart';
import 'package:xs_user/order_provider.dart';
import 'package:xs_user/theme_provider.dart';
import 'package:xs_user/canteen_provider.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/network_buffer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final initializationService = InitializationService();
  final networkBuffer = NetworkBuffer();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => CanteenProvider()),
        ChangeNotifierProvider(create: (context) => MenuProvider()),
        ChangeNotifierProvider(create: (context) => OrderProvider()),
        ChangeNotifierProvider.value(value: networkBuffer),
        ChangeNotifierProvider.value(value: initializationService),
      ],
      child: const MyApp(),
    ),
  );
  Future.microtask(() => initializationService.initializeFirebaseAndGoogle());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _hasSeenOnboardingFuture;

  @override
  void initState() {
    super.initState();
    _hasSeenOnboardingFuture = _checkOnboardingStatus();
  }

  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Namma Canteen',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme),
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
          thumbColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(
                context,
              ).primaryColor.withAlpha((255 * 0.5).round());
            }
            return Colors.grey.withAlpha((255 * 0.5).round());
          }),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark().copyWith(
          primary: const Color(0xFFFF6B35),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
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
          thumbColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).primaryColor;
            }
            return Colors.grey[700];
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(
                context,
              ).primaryColor.withAlpha((255 * 0.5).round());
            }
            return Colors.grey[800];
          }),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _hasSeenOnboardingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == true) {
              return const HomeScreen();
            } else {
              return const OnboardingScreen();
            }
          } else {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}
