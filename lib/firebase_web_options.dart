import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _requiredValue(String dartDefineKey, String envKey) {
  switch (dartDefineKey) {
    case 'FIREBASE_WEB_API_KEY':
      const value = String.fromEnvironment('FIREBASE_WEB_API_KEY');
      if (value.isNotEmpty) return value;
      break;
    case 'FIREBASE_WEB_APP_ID':
      const value = String.fromEnvironment('FIREBASE_WEB_APP_ID');
      if (value.isNotEmpty) return value;
      break;
    case 'FIREBASE_WEB_MESSAGING_SENDER_ID':
      const value = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
      if (value.isNotEmpty) return value;
      break;
    case 'FIREBASE_WEB_PROJECT_ID':
      const value = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
      if (value.isNotEmpty) return value;
      break;
  }

  final envValue = dotenv.env[envKey];
  if (envValue != null && envValue.isNotEmpty) return envValue;
  throw StateError(
    'Missing required Firebase web config: $dartDefineKey/$envKey',
  );
}

String? _optionalValue(String dartDefineKey, String envKey) {
  switch (dartDefineKey) {
    case 'FIREBASE_WEB_AUTH_DOMAIN':
      const value = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
      if (value.isNotEmpty) return value;
      break;
    case 'FIREBASE_WEB_STORAGE_BUCKET':
      const value = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
      if (value.isNotEmpty) return value;
      break;
    case 'FIREBASE_WEB_MEASUREMENT_ID':
      const value = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');
      if (value.isNotEmpty) return value;
      break;
  }

  final envValue = dotenv.env[envKey];
  if (envValue != null && envValue.isNotEmpty) return envValue;
  return null;
}

FirebaseOptions resolveFirebaseWebOptions() {
  return FirebaseOptions(
    apiKey: _requiredValue('FIREBASE_WEB_API_KEY', 'FIREBASE_WEB_API_KEY'),
    appId: _requiredValue('FIREBASE_WEB_APP_ID', 'FIREBASE_WEB_APP_ID'),
    messagingSenderId: _requiredValue(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
    ),
    projectId: _requiredValue(
      'FIREBASE_WEB_PROJECT_ID',
      'FIREBASE_WEB_PROJECT_ID',
    ),
    authDomain: _optionalValue(
      'FIREBASE_WEB_AUTH_DOMAIN',
      'FIREBASE_WEB_AUTH_DOMAIN',
    ),
    storageBucket: _optionalValue(
      'FIREBASE_WEB_STORAGE_BUCKET',
      'FIREBASE_WEB_STORAGE_BUCKET',
    ),
    measurementId: _optionalValue(
      'FIREBASE_WEB_MEASUREMENT_ID',
      'FIREBASE_WEB_MEASUREMENT_ID',
    ),
  );
}
