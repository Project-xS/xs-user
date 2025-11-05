import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _tokenKey = 'firebase_id_token';
  static const String _tokenExpiryKey = 'firebase_id_token_expiry';
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);

  static String? _serverClientId;
  static List<String> _allowedDomains = const [];
  static bool _googleSignInInitialized = false;

  static String? _cachedToken;
  static DateTime? _cachedExpiry;

  static Future<void> configure({
    String? serverClientId,
    List<String> allowedGoogleDomains = const [],
  }) async {
    _serverClientId = (serverClientId != null && serverClientId.isNotEmpty)
        ? serverClientId
        : null;
    _allowedDomains = allowedGoogleDomains.map((d) => d.toLowerCase()).toList();
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );
      _googleSignInInitialized = true;
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final email = account.email;
      if (_allowedDomains.isNotEmpty) {
        final domain = email.split('@').last.toLowerCase();
        if (!_allowedDomains.contains(domain)) {
          await GoogleSignIn.instance.signOut();
          throw AuthException(
            'domain-not-allowed',
            'Please sign in with an allowed organization email.',
          );
        }
      }

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthException(
          'token-missing',
          'Unable to obtain an ID token from Google Sign-In.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user == null) {
        throw AuthException(
          'user-null',
          'Failed to complete sign-in. Please try again.',
        );
      }

      if (user.email == null || !(user.emailVerified)) {
        await signOut();
        throw AuthException(
          'email-not-verified',
          'Your Google account email must be verified before you can sign in.',
        );
      }

      await _persistIdToken(user, forceRefresh: true);
    } on GoogleSignInException catch (error, stack) {
      debugPrint('AuthService.signInWithGoogle Google error: $error');
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException(
          'cancelled',
          'Sign-in was cancelled. Please try again.',
        );
      }
      if (error.code == GoogleSignInExceptionCode.interrupted) {
        throw AuthException(
          'interrupted',
          'Sign-in was interrupted. Please try again.',
        );
      }
      if (error.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw AuthException(
          'ui-unavailable',
          'Sign-in UI is unavailable on this device.',
        );
      }
      FlutterError.presentError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'AuthService',
        context: ErrorDescription('during Google sign-in'),
      ));
      throw AuthException(
        'sign-in-failed',
        'Unable to sign in with Google at this time.',
      );
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('AuthService.signInWithGoogle error: $error');
      throw AuthException(
        'sign-in-failed',
        'Unable to sign in with Google at this time.',
      );
    }
  }

  static Future<bool> isGoogleSessionValid() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    final token = await getValidIdToken();
    return token != null;
  }

  static Future<String?> getValidIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      debugPrint('AuthService.getValidIdToken: No Firebase user');
      return null;
    }

    if (!forceRefresh) {
      await _ensureTokenLoaded();
      if (_cachedToken != null && _cachedExpiry != null) {
        final now = DateTime.now();
        if (now.isBefore(_cachedExpiry!.subtract(_tokenRefreshBuffer))) {
          debugPrint('AuthService.getValidIdToken: Using cached token');
          return _cachedToken;
        }
        debugPrint('AuthService.getValidIdToken: Cached token expired, refreshing');
      } else {
        debugPrint('AuthService.getValidIdToken: No cached token found');
      }
    }

    try {
      final token = await _persistIdToken(user, forceRefresh: true);
      debugPrint('AuthService.getValidIdToken: Token refreshed successfully');
      return token;
    } catch (e) {
      debugPrint('AuthService.getValidIdToken refresh error: $e');
    }

    try {
      final token = await _persistIdToken(user, forceRefresh: false);
      debugPrint('AuthService.getValidIdToken: Token obtained via fallback');
      return token;
    } catch (e) {
      debugPrint('AuthService.getValidIdToken fallback error: $e');
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await signOut();
  }

  static Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut Firebase error: $e');
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut Google error: $e');
    }

    await _clearCachedToken();
  }

  static Future<String> _persistIdToken(
    User user, {
    required bool forceRefresh,
  }) async {
    debugPrint(
      'AuthService._persistIdToken: forceRefresh=$forceRefresh, userEmail=${user.email}',
    );
    final result = await user.getIdTokenResult(forceRefresh);
    final token = result.token;
    final expirationTime = result.expirationTime;

    if (token == null) {
      debugPrint('AuthService._persistIdToken: Token is null from getIdTokenResult');
      throw AuthException(
        'token-missing',
        'Unable to fetch an ID token for the user.',
      );
    }

    debugPrint(
      'AuthService._persistIdToken: Token obtained, expires at $expirationTime',
    );
    _cachedToken = token;
    _cachedExpiry = expirationTime;

    if (!kIsWeb) {
      await _secureStorage.write(key: _tokenKey, value: token);
      if (expirationTime != null) {
        await _secureStorage.write(
          key: _tokenExpiryKey,
          value: expirationTime.toIso8601String(),
        );
      } else {
        await _secureStorage.delete(key: _tokenExpiryKey);
      }
    }
    return token;
  }

  static Future<void> _ensureTokenLoaded() async {
    if (_cachedToken != null && _cachedExpiry != null) return;
    if (kIsWeb) return;

    try {
      final token = await _secureStorage.read(key: _tokenKey);
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      DateTime? expiry;
      if (expiryString != null) {
        expiry = DateTime.tryParse(expiryString);
      }
      if (token != null && expiry != null) {
        _cachedToken = token;
        _cachedExpiry = expiry;
      }
    } catch (e) {
      debugPrint('AuthService._ensureTokenLoaded error: $e');
    }
  }

  static Future<void> _clearCachedToken() async {
    _cachedToken = null;
    _cachedExpiry = null;
    if (!kIsWeb) {
      try {
        await _secureStorage.delete(key: _tokenKey);
        await _secureStorage.delete(key: _tokenExpiryKey);
      } catch (e) {
        debugPrint('AuthService._clearCachedToken error: $e');
      }
    }
  }
}
