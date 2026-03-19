import 'dart:convert';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhonePeService {
  static String get _environment {
    const dartDefine = String.fromEnvironment('PHONEPE_ENVIRONMENT');
    if (dartDefine.isNotEmpty) return dartDefine;
    return (dotenv.env['PHONEPE_ENVIRONMENT'] ?? 'SANDBOX').trim();
  }

  static String get _merchantId {
    const dartDefine = String.fromEnvironment('PHONEPE_MERCHANT_ID');
    if (dartDefine.isNotEmpty) return dartDefine;
    return (dotenv.env['PHONEPE_MERCHANT_ID'] ?? 'TEST').trim();
  }

  static const String _appSchema = 'xsuser';

  static bool _isInitialized = false;

  static Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }

      final enableLogging = _environment == 'SANDBOX';

      _isInitialized = await PhonePePaymentSdk.init(
        _environment,
        _merchantId,
        _appSchema,
        enableLogging,
      );

      debugPrint('PhonePe SDK Initialized: $_isInitialized in $_environment mode');
      return _isInitialized;
    } catch (e) {
      debugPrint('PhonePe Initialization Error: $e');
      return false;
    }
  }

  static Future<Map<dynamic, dynamic>?> startTransaction({
    required String orderId,
    required String merchantId,
    required String token,
  }) async {
    await init();

    final sdkPayload = jsonEncode({
      'orderId': orderId,
      'merchantId': merchantId,
      'token': token,
      'paymentMode': {'type': 'PAY_PAGE'},
    });

    return await PhonePePaymentSdk.startTransaction(sdkPayload, _appSchema);
  }
}
