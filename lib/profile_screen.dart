import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xs_user/login_screen.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/orders_list_screen.dart';
import 'package:xs_user/theme_provider.dart';

import 'package:xs_user/help_and_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<User> _loadUser() async {
    // final prefs = await SharedPreferences.getInstance();
    // final userId = prefs.getInt('userId');
    // int userId = 1;
    // if (userId != null) {
    //   return ApiService().getUser(userId);
    // } else {
      return Future.value(User(
        id: 1,
        rfid: '1234567890',
        name: 'John Durairaj',
        email: 'JD@citchennai.net',
      ));
    // }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            return Column(
              children: [
                const SizedBox(height: 24),
                const CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(
                      'https://w0.peakpx.com/wallpaper/725/191/HD-wallpaper-master-vijay-jd-thalapathy.jpg'),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                _buildProfileMenuItem(
                  context,
                  icon: Icons.receipt_long,
                  text: 'My Orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersListScreen(showBackButton: true),
                      ),
                    );
                  },
                ),
                _buildProfileMenuItem(
                  context,
                  icon: Icons.help_outline,
                  text: 'Help & Support',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpAndSupportScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Switch(
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                    },
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                _buildProfileMenuItem(
                  context,
                  icon: Icons.logout,
                  text: 'Logout',
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', false);
                    if (context.mounted){
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );}
                  },
                  isLogout: true,
                ),
              ],
            );
          } else {
            return const Center(child: Text('No user data found.'));
          }
        },
      ),
    );
  }

  Widget _buildProfileMenuItem(BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout ? Theme.of(context).colorScheme.error : Theme.of(context).iconTheme.color,
      ),
      title: Text(
        text,
        style: GoogleFonts.montserrat(
          color: isLogout ? Theme.of(context).colorScheme.error : Theme.of(context).textTheme.titleMedium?.color,
          fontSize: 16,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).iconTheme.color, size: 16),
      onTap: onTap,
    );
  }
}