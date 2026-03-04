import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhonePeService {
  static String get _mId => (dotenv.env['PHONEPE_MERCHANT_ID'] ?? 'PGTESTPAYUAT86').trim();
  static String get _cId => (dotenv.env['PHONEPE_CLIENT_ID'] ?? 'PGTESTPAYUAT86').trim();
  static String get _cSecret => (dotenv.env['PHONEPE_CLIENT_SECRET'] ?? '96434309-7796-489d-8924-ab56988a6076').trim();
  
  static String get _pgBaseUrl => (dotenv.env['PHONEPE_PG_BASE_URL'] ?? 'https://api-preprod.phonepe.com/apis/pg-sandbox').trim();
  static String get _authBaseUrl => (dotenv.env['PHONEPE_AUTH_BASE_URL'] ?? 'https://api-preprod.phonepe.com/apis/pg-sandbox').trim();
  
  static String get _environment => (dotenv.env['PHONEPE_ENVIRONMENT'] ?? 'SANDBOX').trim();
  static String get _appSchema => (dotenv.env['PHONEPE_APP_SCHEMA'] ?? 'xsuser').trim();

  static bool _isInitialized = false;

  static Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }
      
      String appId = (dotenv.env['PHONEPE_APP_ID'] ?? "").trim();
      
      // DISCOVERED SIGNATURE for 3.0.x: (environment, appId, merchantId, enableLogging)
      // Log confirmed third parameter is used as 'mid'
      _isInitialized = await PhonePePaymentSdk.init(
        _environment, 
        appId, 
        _mId, 
        true
      );
      
      debugPrint('PhonePe SDK Initialized: $_isInitialized in $_environment mode');
      return _isInitialized;
    } catch (e) {
      debugPrint('PhonePe Initialization Error: $e');
      return false;
    }
  }

  static Future<String> _getAuthToken() async {
    try {
      // Using raw string for x-www-form-urlencoded to avoid DESERIALIZATION_ERROR
      final String body = 'grant_type=client_credentials&client_id=$_cId&client_secret=$_cSecret';
      
      final response = await http.post(
        Uri.parse('$_authBaseUrl/v1/oauth/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        debugPrint("OAUTH ERROR: ${response.statusCode} - ${response.body}");
        
        // Fallback: retry with JSON if still failing
        if (response.statusCode == 415 || response.statusCode == 400) {
           debugPrint("Retrying OAuth with JSON body...");
           final retryResponse = await http.post(
            Uri.parse('$_authBaseUrl/v1/oauth/token'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode({
              'client_id': _cId,
              'client_secret': _cSecret,
              'grant_type': 'client_credentials',
            }),
          );
          if (retryResponse.statusCode == 200) {
            return jsonDecode(retryResponse.body)['access_token'];
          }
          debugPrint("RETRY OAUTH ERROR: ${retryResponse.statusCode} - ${retryResponse.body}");
        }
        throw Exception("PhonePe OAuth Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("NETWORK ERROR in _getAuthToken: $e");
      rethrow;
    }
  }

  static Future<Map<dynamic, dynamic>?> startPayment({
    required double amount,
    required String merchantTransactionId,
  }) async {
    try {
      await init();
      final String oauthToken = await _getAuthToken();
      final int amountInPaisa = (amount * 100).toInt();

      final payBody = {
        "merchantOrderId": merchantTransactionId,
        "amount": amountInPaisa,
        "paymentFlow": {
          "type": "PG_CHECKOUT",
          "merchantUrls": {
            "redirectUrl": "com.nammacanteen.user://payment-success",
            "callbackUrl": "https://www.google.com" 
          }
        }
      };

      final orderResponse = await http.post(
        Uri.parse('$_pgBaseUrl/checkout/v2/sdk/order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'O-Bearer ${oauthToken.trim()}',
        },
        body: jsonEncode(payBody),
      );

      if (orderResponse.statusCode == 200 || orderResponse.statusCode == 201) {
        final orderData = jsonDecode(orderResponse.body);
        final String sdkToken = orderData['token']; 

        Map<String, dynamic> sdkPayload = {
          "merchantId": _mId,
          "orderId": orderData['orderId'],
          "token": sdkToken,
        };

        return await PhonePePaymentSdk.startTransaction(
          jsonEncode(sdkPayload), 
          _appSchema
        );
      } else {
        debugPrint("PhonePe Order API Failed: ${orderResponse.body}");
        return {'status': 'ERROR', 'message': 'Order creation failed'};
      }
    } catch (e) {
      debugPrint("Payment Error: $e");
      return {'status': 'ERROR', 'message': e.toString()};
    }
  }
}
