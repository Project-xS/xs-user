import 'package:url_launcher/url_launcher.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/payment/payment_launcher.dart';

Future<PaymentLaunchResult> launchPayment(
  PaymentInitiateResponse response,
) async {
  final paymentUrl = response.paymentUrl;
  if (paymentUrl == null || paymentUrl.isEmpty) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Missing web payment URL from backend.',
    );
  }

  final uri = Uri.tryParse(paymentUrl);
  if (uri == null) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Invalid web payment URL.',
    );
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Unable to open payment page.',
    );
  }

  return const PaymentLaunchResult(success: true, requiresConfirmation: true);
}
