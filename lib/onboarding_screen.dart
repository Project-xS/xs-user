import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:xs_user/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: Text(
                  'Skip',
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  OnboardingPage(
                    icon: Icons.food_bank_outlined,
                    iconColor: const Color(0xFFFF7A3A),
                    title: 'Multiple Canteens',
                    subtitle: 'Explore food from all campus canteens',
                    description:
                        'Browse through various canteens across campus and\ndiscover delicious meals from your favorite spots.',
                    textColor: Theme.of(context).textTheme.titleLarge?.color,
                    subtitleColor: const Color(0xFFFF7A3A),
                    descriptionColor: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  OnboardingPage(
                    icon: Icons.schedule,
                    iconColor: const Color(0xFF4C8DFF),
                    title: 'Smart Preordering',
                    subtitle: 'Skip the queue with time slots',
                    description:
                        'Pre-order your meals for specific time slots (11-12pm or 12-1pm) and have them ready when you arrive.',
                    textColor: Theme.of(context).textTheme.titleLarge?.color,
                    subtitleColor: const Color(0xFFFF7A3A),
                    descriptionColor: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  OnboardingPage(
                    icon: Icons.search,
                    iconColor: const Color(0xFF14C38E),
                    title: 'Easy Discovery',
                    subtitle: 'Find your perfect meal',
                    description:
                        'Use our smart search and filters to quickly find exactly what you\'re craving from any canteen.',
                    textColor: Theme.of(context).textTheme.titleLarge?.color,
                    subtitleColor: const Color(0xFFFF7A3A),
                    descriptionColor: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => buildDot(index, context)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_currentPage < 2) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
              child: Container(
                width: 200,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(0, 6),
                      blurRadius: 18,
                      color: Color.fromRGBO(0, 0, 0, 0.45),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentPage == 2 ? 'Get Started' : 'Next',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_currentPage != 2)
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Container buildDot(int index, BuildContext context) {
    return Container(
      height: 8,
      width: _currentPage == index ? 16 : 8,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _currentPage == index
            ? const Color(0xFFFF7A3A)
            : Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((255 * 0.5).round()),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final Color? textColor;
  final Color? subtitleColor;
  final Color? descriptionColor;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    this.textColor,
    this.subtitleColor,
    this.descriptionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor,
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, 6),
                  blurRadius: 18,
                  color: Color.fromRGBO(0, 0, 0, 0.4),
                )
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.montserrat(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.montserrat(
              color: subtitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: descriptionColor,
              fontSize: 13,
            ),
          )
        ],
      ),
    );
  }
}