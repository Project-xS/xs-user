import 'package:flutter/foundation.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum InitializationStatus { uninitialized, initializing, initialized, error }

class InitializationService extends ChangeNotifier {
  static final InitializationService _instance = InitializationService._internal();
  factory InitializationService() => _instance;
  InitializationService._internal();

  InitializationStatus _status = InitializationStatus.uninitialized;
  InitializationStatus get status => _status;

  bool get isInitialized => _status == InitializationStatus.initialized;

  Future<void> initializeSupabaseAndGoogle() async {
    if (_status != InitializationStatus.uninitialized) return;

    _status = InitializationStatus.initializing;
    notifyListeners();

    try {
      await dotenv.load(fileName: ".env");
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
      // await GoogleSignIn.instance.initialize(
      //   serverClientId: dotenv.env['SERVER_CLIENT_ID'],
      // );

      _status = InitializationStatus.initialized;
    } catch (e) {
      _status = InitializationStatus.error;
      debugPrint('Initialization failed: $e');
    }

    notifyListeners();
  }
}
