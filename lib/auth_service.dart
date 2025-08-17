import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static Future<bool> isGoogleSessionValid() async {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.providerToken == null) {
      return false;
    }
    final accessToken = session.providerToken!;
    final res = await http.get(
      Uri.parse("${dotenv.env['AUTH_VERIFY']}?access_token=$accessToken"),
    );
    debugPrint("Initial verify: ${res.body}");
    if (res.statusCode == 200) {
      return true;
    }
    final AuthResponse response = await Supabase.instance.client.auth.refreshSession();
    final newSession = response.session;
    if (newSession == null || newSession.providerToken == null) {
      debugPrint('AuthService: Auth might be revoken');
      return false;
    }
    final res2 = await http.get(
      Uri.parse("${dotenv.env['AUTH_VERIFY']}?access_token=${newSession.providerToken}"),
    );
    debugPrint("After refresh verify: ${res2.body}");
    return res2.statusCode == 200;
    } catch (e) {
      debugPrint('AuthService: An exception occurred during session validation: $e');
      return false;
    }
  }
}

      // final googleUser = await GoogleSignIn.instance.attemptLightweightAuthentication();
      // if (googleUser == null) {
      //   debugPrint('AuthService: Lightweight auth returned null. User is not signed in.');
      //   return false;
      // }
      // final authClient = googleUser.authorizationClient;
      // final clientAuth = await authClient.authorizationForScopes(['email']);
      
      // if (clientAuth == null) {
      //   debugPrint('AuthService: Could not get authorization for scopes silently. Session is likely invalid.');
      //   return false;
      // }
      // final accessToken = clientAuth.accessToken;
      // final response = await http.get(
      //   Uri.parse(dotenv.env['AUTH_VERIFY']!+accessToken),
      // );

      // debugPrint('AuthService: Google token validation response: ${response.statusCode}');
      // return response.statusCode == 200;