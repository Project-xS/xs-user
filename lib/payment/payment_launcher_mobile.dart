import 'package:xs_user/models.dart';
import 'package:xs_user/payment/payment_launcher.dart';
import 'package:xs_user/phonepe_service.dart';

Future<PaymentLaunchResult> launchPayment(
  PaymentInitiateResponse response,
) async {
  if (response.orderId == null ||
      response.merchantId == null ||
      response.token == null) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Missing mobile payment payload from backend.',
    );
  }

  final result = await PhonePeService.startTransaction(
    orderId: response.orderId!,
    merchantId: response.merchantId!,
    token: response.token!,
  );

  if (result == null || result['status'] != 'SUCCESS') {
    return PaymentLaunchResult(
      success: false,
      message: result?['message']?.toString() ?? 'Payment failed or cancelled.',
    );
  }

  return const PaymentLaunchResult(success: true);
}
