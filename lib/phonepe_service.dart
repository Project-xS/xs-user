import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhonePeService {
  static String get _mId => (dotenv.env['PHONEPE_MERCHANT_ID'] ?? 'PGTESTPAYUAT86').trim();
  static String get _cId => (dotenv.env['PHONEPE_CLIENT_ID'] ?? 'PGTESTPAYUAT86').trim();
  static String get _cSecret => (dotenv.env['PHONEPE_CLIENT_SECRET'] ?? '96434309-7796-489d-8924-ab56988a6076').trim();
  
  static String get _pgBaseUrl => 'https://api-preprod.phonepe.com/apis/pg-sandbox';
  static String get _authBaseUrl => 'https://api-preprod.phonepe.com/apis/pg-sandbox';
  
  static String get _environment =>'SANDBOX';
  static String get _appSchema => 'xsuser';

  static bool _isInitialized = false;

  static Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }
      
      String appId = (dotenv.env['PHONEPE_APP_ID'] ?? "").trim();
      
      // Signature: (environment, appId, merchantId, enableLogging)
      _isInitialized = await PhonePePaymentSdk.init(
        _environment, 
        _mId,
        'test',
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
      final response = await http.post(
        Uri.parse('$_authBaseUrl/v1/oauth/token?client_version=1&grant_type=client_credentials&client_id=$_cId&client_secret=$_cSecret'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          // 'Accept': '*/*',
          // 'Origin': 'https://developer.phonepe.com',
          // 'Referer': 'https://developer.phonepe.com/',
          // 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        },
        // body: {
        //   'client_version': '1',
        //   'grant_type': 'client_credentials',
        //   'client_id': _cId,
        //   'client_secret': _cSecret,
        // },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('OAuth Token Response: $data');
        return data['access_token'];
      } else {
        debugPrint("OAUTH ERROR: ${response.statusCode} - ${response.body}");
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
        "amount": amountInPaisa,
        "expireAfter": 1200,
        "paymentFlow": {
          "type": "PG_CHECKOUT"
        },
        "enabledPaymentModes": [{
          "type": "UPI_INTENT"
          },],
        "merchantOrderId": merchantTransactionId
      };

      final orderResponse = await http.post(
        Uri.parse('$_pgBaseUrl/checkout/v2/sdk/order'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'O-Bearer ${oauthToken.trim()}',
        },
        body: jsonEncode(payBody),
      );

      if (orderResponse.statusCode == 200 || orderResponse.statusCode == 201) {
        final orderData = jsonDecode(orderResponse.body);
        final String sdkToken = orderData['token']; 

        Map<String, dynamic> sdkPayload = {
          "orderId": orderData['orderId'],
          "merchantId": _mId,
          "token": sdkToken,
          "paymentMode": {"type": "PAY_PAGE"}
        };

        return await PhonePePaymentSdk.startTransaction(
          jsonEncode(sdkPayload), 
          'test'
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
