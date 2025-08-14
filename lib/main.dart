
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/home_screen.dart';
import 'package:xs_user/onboarding_screen.dart';
import 'package:xs_user/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

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
      home: isLoggedIn ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
