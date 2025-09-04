import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Access the singleton GoogleSignIn instance (configured during app init).
  static GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  // Native, redirectless Google sign-in that exchanges idToken with Supabase.
  static Future<void> signInWithGoogle() async {
    try {
      // Trigger interactive authentication.
      final account = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Unable to obtain Google idToken.');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle error: $e');
      rethrow;
    }
  }

  // Checks Supabase session validity and refreshes if needed.
  static Future<bool> isGoogleSessionValid() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) return false;

      final expiresAt = session.expiresAt; // seconds since epoch
      if (expiresAt == null) return true; // assume valid if unknown
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: false);

      // Refresh a bit early to be safe.
      if (DateTime.now().isBefore(expiry.subtract(const Duration(seconds: 30)))) {
        return true;
      }

      final res = await client.auth.refreshSession();
      return res.session != null;
    } catch (e) {
      debugPrint('AuthService.isGoogleSessionValid error: $e');
      return false;
    }
  }

  // Signs out of the native Google session used for sign-in.
  static Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('AuthService.signOutGoogle error: $e');
    }
  }
}
