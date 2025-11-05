import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xs_user/auth_service.dart';

enum InitializationStatus { uninitialized, initializing, initialized, error }

class InitializationService extends ChangeNotifier {
  static final InitializationService _instance =
      InitializationService._internal();
  factory InitializationService() => _instance;
  InitializationService._internal();

  InitializationStatus _status = InitializationStatus.uninitialized;
  InitializationStatus get status => _status;

  bool get isInitialized => _status == InitializationStatus.initialized;
  List<String> get allowedDomains => _allowedDomains;

  List<String> _allowedDomains = const [];

  Future<void> initializeFirebaseAndGoogle() async {
    if (_status != InitializationStatus.uninitialized) return;

    _status = InitializationStatus.initializing;
    notifyListeners();

    try {
      await dotenv.load(fileName: ".env");
      _allowedDomains = _parseAllowedDomains(
        dotenv.env['ALLOWED_GOOGLE_DOMAINS'],
      );

      await Firebase.initializeApp();

      final serverClientId = dotenv.env['SERVER_CLIENT_ID'];
      if (serverClientId != null && serverClientId.isEmpty) {
        throw Exception('SERVER_CLIENT_ID provided but empty in .env');
      }

      await AuthService.configure(
        serverClientId: serverClientId,
        allowedGoogleDomains: _allowedDomains,
      );

      _status = InitializationStatus.initialized;
    } catch (e) {
      _status = InitializationStatus.error;
      debugPrint('Initialization failed: $e');
    }

    notifyListeners();
  }

  List<String> _parseAllowedDomains(String? domains) {
    if (domains == null || domains.trim().isEmpty) return const [];
    final parsed = domains
        .split(',')
        .map((domain) => domain.trim().toLowerCase())
        .where((domain) => domain.isNotEmpty)
        .toList();
    return List.unmodifiable(parsed);
  }
}
