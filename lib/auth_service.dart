import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static DateTime? _tokenExpirationTime;

  static Future<bool> isGoogleSessionValid() async {
    if (_tokenExpirationTime != null &&
        DateTime.now().isBefore(_tokenExpirationTime!)) {
      return true;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.providerToken == null) {
        return false;
      }
      final accessToken = session.providerToken!;
      final res = await http.get(
        Uri.parse("https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=$accessToken"),
      );
      debugPrint("Initial verify: ${res.body}");
      if (res.statusCode == 200) {
        final expiresIn = jsonDecode(res.body)['expires_in'];
        _tokenExpirationTime = DateTime.now().add(Duration(seconds: expiresIn));
        return true;
      }
      final AuthResponse response = await Supabase.instance.client.auth.refreshSession();
      final newSession = response.session;
      if (newSession == null || newSession.providerToken == null) {
        debugPrint('AuthService: Auth might be revoken');
        return false;
      }
      final res2 = await http.get(
        Uri.parse("https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${newSession.providerToken}"),
      );
      debugPrint("After refresh verify: ${res2.body}");
      if (res2.statusCode == 200) {
        final expiresIn = jsonDecode(res2.body)['expires_in'];
        _tokenExpirationTime = DateTime.now().add(Duration(seconds: expiresIn));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AuthService: An exception occurred during session validation: $e');
      return false;
    }
  }
}