import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:xs_user/models.dart';
import 'package:xs_user/payment/payment_launcher.dart';

const String _checkoutMethodName = 'checkout';
const String _iframeMode = 'IFRAME';

Future<PaymentLaunchResult> launchPayment(
  PaymentInitiateResponse response,
) async {
  final tokenUrl = response.webCheckoutTokenUrl;
  if (tokenUrl == null || tokenUrl.isEmpty) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Missing web checkout token URL from backend.',
    );
  }

  if (!_hasCheckoutBridge()) {
    return const PaymentLaunchResult(
      success: false,
      message: 'PhonePe checkout bridge is not available on this page.',
    );
  }

  final completer = Completer<PaymentLaunchResult>();
  final callback = ((JSAny? responseCode) {
    if (completer.isCompleted) return;
    final status = _normalizeResponseCode(responseCode).toUpperCase();
    switch (status) {
      case 'CONCLUDED':
        completer.complete(const PaymentLaunchResult(success: true));
        break;
      case 'USER_CANCEL':
        completer.complete(
          const PaymentLaunchResult(
            success: false,
            message: 'Payment was cancelled.',
          ),
        );
        break;
      case 'CHECKOUT_UNAVAILABLE':
        completer.complete(
          const PaymentLaunchResult(
            success: false,
            message: 'PhonePe checkout script is unavailable.',
          ),
        );
        break;
      case 'CHECKOUT_INVOKE_ERROR':
        completer.complete(
          const PaymentLaunchResult(
            success: false,
            message: 'Unable to start PhonePe checkout.',
          ),
        );
        break;
      default:
        completer.complete(
          PaymentLaunchResult(
            success: false,
            message: 'Unexpected payment callback: $status',
          ),
        );
    }
  }).toJS;

  try {
    globalContext.callMethod(
      _checkoutMethodName.toJS,
      tokenUrl.toJS,
      _iframeMode.toJS,
      callback,
    );
  } catch (_) {
    return const PaymentLaunchResult(
      success: false,
      message: 'Failed to invoke web checkout.',
    );
  }

  return completer.future.timeout(
    const Duration(minutes: 10),
    onTimeout: () => const PaymentLaunchResult(
      success: false,
      message: 'Timed out waiting for payment completion.',
    ),
  );
}

bool _hasCheckoutBridge() {
  return globalContext.hasProperty(_checkoutMethodName.toJS).toDart;
}

String _normalizeResponseCode(JSAny? value) {
  if (value == null) return '';
  try {
    final maybeString = globalContext.callMethod('String'.toJS, value);
    return (maybeString as JSString).toDart;
  } catch (_) {
    return '';
  }
}
