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
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }

      const rawAllowedDomains = String.fromEnvironment('ALLOWED_GOOGLE_DOMAINS');
      final envAllowedDomains = dotenv.env['ALLOWED_GOOGLE_DOMAINS'];
      final allowedDomainsValue =
          rawAllowedDomains.isNotEmpty ? rawAllowedDomains : envAllowedDomains;
      _allowedDomains = _parseAllowedDomains(allowedDomainsValue);

      await Firebase.initializeApp();

      const serverClientId = String.fromEnvironment('SERVER_CLIENT_ID');
      final envServerClientId = dotenv.env['SERVER_CLIENT_ID'];
      final effectiveServerClientId =
          serverClientId.isNotEmpty ? serverClientId : envServerClientId;

      await AuthService.configure(
        serverClientId:
            (effectiveServerClientId != null &&
                    effectiveServerClientId.isNotEmpty)
                ? effectiveServerClientId
                : null,
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
