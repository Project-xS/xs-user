import 'package:xs_user/models.dart';

import 'payment_launcher_mobile.dart'
    if (dart.library.html) 'payment_launcher_web.dart'
    as impl;

class PaymentLaunchResult {
  final bool success;
  final bool requiresConfirmation;
  final String? message;

  const PaymentLaunchResult({
    required this.success,
    this.requiresConfirmation = false,
    this.message,
  });
}

Future<PaymentLaunchResult> launchPayment(
  PaymentInitiateResponse response,
) async {
  return impl.launchPayment(response);
}
