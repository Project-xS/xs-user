import 'package:xs_user/models.dart';

enum PaymentVerificationState { success, pending, failed }

class PaymentVerificationOutcome {
  final PaymentVerificationState state;
  final int? orderId;
  final String message;

  const PaymentVerificationOutcome({
    required this.state,
    required this.message,
    this.orderId,
  });
}

bool isValidPaymentInitiateResponse(
  PaymentInitiateResponse response, {
  required bool isWeb,
}) {
  if (response.status != 'ok') return false;
  if (response.merchantOrderId == null || response.merchantOrderId!.isEmpty) {
    return false;
  }
  if (isWeb) {
    return response.webCheckoutTokenUrl != null;
  }
  return response.orderId != null &&
      response.token != null &&
      response.merchantId != null;
}

String paymentInitiateError(
  PaymentInitiateResponse response, {
  required bool isWeb,
}) {
  if (response.error != null && response.error!.isNotEmpty) {
    return response.error!;
  }
  return isWeb
      ? 'Failed to initiate web payment.'
      : 'Failed to initiate app payment.';
}

PaymentVerificationOutcome parsePaymentVerification(
  PaymentVerifyResponse response,
) {
  if (response.status == 'ok' && response.orderId != null) {
    return PaymentVerificationOutcome(
      state: PaymentVerificationState.success,
      orderId: response.orderId,
      message: 'Payment successful.',
    );
  }

  final paymentState = (response.paymentState ?? '').toUpperCase();
  if (paymentState == 'PENDING') {
    return PaymentVerificationOutcome(
      state: PaymentVerificationState.pending,
      message: response.error ?? 'Payment is pending confirmation.',
    );
  }

  return PaymentVerificationOutcome(
    state: PaymentVerificationState.failed,
    message: response.error ?? 'Payment verification failed.',
  );
}
