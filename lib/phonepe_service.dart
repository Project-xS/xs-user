import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:flutter/foundation.dart';

class PhonePeService {
  static final String _environment = dotenv.env['PHONEPE_ENVIRONMENT'] ?? 'SANDBOX';
  static final String _merchantId = dotenv.env['PHONEPE_MERCHANT_ID'] ?? '';
  static final String _saltKey = dotenv.env['PHONEPE_SALT_KEY'] ?? '';
  static final String _appId = dotenv.env['PHONEPE_APP_ID'] ?? '';
  static final String _saltIndex = dotenv.env['PHONEPE_SALT_INDEX'] ?? '1';
  static final String _callbackUrl = dotenv.env['PHONEPE_CALLBACK_URL'] ?? '';

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    // Passing 4 arguments as per PhonePe SDK 3.0.x documentation
    _isInitialized = await PhonePePaymentSdk.init(
      _environment,
      _appId,
      _merchantId,
      true, // Enable logging
    );
    debugPrint('PhonePe SDK Initialized: $_isInitialized');
  }

  static Future<Map<dynamic, dynamic>?> startPayment({
    required String transactionId,
    required double amount,
    required String userId,
    String? mobileNumber,
  }) async {
    await init();

    final int amountInPaise = (amount * 100).toInt();

    final requestBody = {
      "merchantId": _merchantId,
      "merchantTransactionId": transactionId,
      "merchantUserId": userId,
      "amount": amountInPaise,
      "callbackUrl": _callbackUrl,
      "mobileNumber": mobileNumber,
      "paymentInstrument": {"type": "UPI_INTENT"}
    };

    String base64Body = base64.encode(utf8.encode(json.encode(requestBody)));
    String checksum = _calculateChecksum(base64Body, "/pg/v1/pay");

    try {
      // Exactly 2 positional arguments: request and appSchema (or checksum)
      final response = await PhonePePaymentSdk.startTransaction(base64Body, checksum);
      return response;
    } catch (e) {
      debugPrint('PhonePe Payment Error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static String _calculateChecksum(String base64Body, String apiEndPoint) {
    String rawData = base64Body + apiEndPoint + _saltKey;
    var bytes = utf8.encode(rawData);
    var digest = sha256.convert(bytes);
    return "${digest.toString()}###$_saltIndex";
  }
}
