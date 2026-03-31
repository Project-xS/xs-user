import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/home_screen.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/order_provider.dart';
import 'package:xs_user/order_screen_success.dart';
import 'package:xs_user/payment/payment_flow.dart';

enum PaymentReturnStage { loading, pending, failed, invalid, authRequired }

class PaymentReturnScreen extends StatefulWidget {
  const PaymentReturnScreen({super.key});

  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  PaymentReturnStage _stage = PaymentReturnStage.loading;
  String _message = 'Verifying payment...';

  @override
  void initState() {
    super.initState();
    Future.microtask(_verifyFromReturnContext);
  }

  Future<void> _verifyFromReturnContext() async {
    if (!mounted) return;
    setState(() {
      _stage = PaymentReturnStage.loading;
      _message = 'Verifying payment...';
    });

    try {
      final callbackContext = _parseCallbackContext(Uri.base);
      if (callbackContext == null) {
        if (!mounted) return;
        setState(() {
          _stage = PaymentReturnStage.invalid;
          _message =
              'Missing callback fields: hold_id and merchant_order_id are required.';
        });
        return;
      }

      final initializationService = InitializationService();
      await _ensureInitialized(initializationService);
      if (initializationService.status == InitializationStatus.error) {
        if (!mounted) return;
        setState(() {
          _stage = PaymentReturnStage.failed;
          _message = 'Initialization failed. Please restart the app.';
        });
        return;
      }

      final isSessionValid = await AuthService.isGoogleSessionValid();
      if (!isSessionValid) {
        if (!mounted) return;
        setState(() {
          _stage = PaymentReturnStage.authRequired;
          _message = 'Session expired. Please sign in again.';
        });
        return;
      }

      final verifyResponse = await ApiService().verifyPayment(
        callbackContext.holdId,
        callbackContext.merchantOrderId,
      );
      final outcome = parsePaymentVerification(verifyResponse);

      switch (outcome.state) {
        case PaymentVerificationState.success:
          if (outcome.orderId == null) {
            if (!mounted) return;
            setState(() {
              _stage = PaymentReturnStage.failed;
              _message = 'Payment was marked successful without order details.';
            });
            return;
          }
          if (!mounted) return;
          Provider.of<OrderProvider>(context, listen: false).fetchOrders(
            force: true,
          );
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(orderId: outcome.orderId!),
            ),
            (route) => false,
          );
          return;
        case PaymentVerificationState.pending:
          if (!mounted) return;
          setState(() {
            _stage = PaymentReturnStage.pending;
            _message = outcome.message;
          });
          return;
        case PaymentVerificationState.failed:
          if (!mounted) return;
          setState(() {
            _stage = PaymentReturnStage.failed;
            _message = outcome.message;
          });
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = PaymentReturnStage.failed;
        _message = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  _PaymentReturnCallbackContext? _parseCallbackContext(Uri uri) {
    final params = <String, String>{};
    params.addAll(uri.queryParameters);
    params.addAll(_parseFragmentParams(uri.fragment));

    final holdIdRaw = _firstNonEmpty(
      params,
      const ['hold_id', 'holdId', 'holdid'],
    );
    final merchantOrderId = _firstNonEmpty(
      params,
      const ['merchant_order_id', 'merchantOrderId', 'merchantorderid'],
    );

    if (holdIdRaw == null || merchantOrderId == null) return null;
    final holdId = int.tryParse(holdIdRaw);
    if (holdId == null) return null;

    return _PaymentReturnCallbackContext(
      holdId: holdId,
      merchantOrderId: merchantOrderId,
    );
  }

  Map<String, String> _parseFragmentParams(String fragment) {
    if (fragment.isEmpty) return const {};
    final raw = fragment.startsWith('?')
        ? fragment.substring(1)
        : fragment.startsWith('#')
        ? fragment.substring(1)
        : fragment;
    if (raw.isEmpty) return const {};

    final result = <String, String>{};
    for (final part in raw.split('&')) {
      if (part.isEmpty) continue;
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = Uri.decodeQueryComponent(part.substring(0, index));
      final value = Uri.decodeQueryComponent(part.substring(index + 1));
      result[key] = value;
    }
    return result;
  }

  String? _firstNonEmpty(Map<String, String> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<void> _ensureInitialized(InitializationService service) async {
    if (service.status == InitializationStatus.uninitialized) {
      await service.initializeFirebaseAndGoogle();
      return;
    }
    if (service.status != InitializationStatus.initializing) return;

    final completer = Completer<void>();
    void listener() {
      if (service.status != InitializationStatus.initializing) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        service.removeListener(listener);
      }
    }

    service.addListener(listener);
    if (service.status != InitializationStatus.initializing) {
      service.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    await completer.future;
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _stage == PaymentReturnStage.loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Verifying your payment...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForStage(_stage),
                      size: 54,
                      color: _colorForStage(_stage, colorScheme),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _titleForStage(_stage),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (_stage == PaymentReturnStage.pending)
                      ElevatedButton(
                        onPressed: _verifyFromReturnContext,
                        child: const Text('Check Again'),
                      ),
                    if (_stage != PaymentReturnStage.loading)
                      TextButton(
                        onPressed: _goHome,
                        child: const Text('Back to Home'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _titleForStage(PaymentReturnStage stage) {
    switch (stage) {
      case PaymentReturnStage.loading:
        return 'Checking Payment';
      case PaymentReturnStage.pending:
        return 'Payment Pending';
      case PaymentReturnStage.failed:
        return 'Payment Failed';
      case PaymentReturnStage.invalid:
        return 'Payment Not Found';
      case PaymentReturnStage.authRequired:
        return 'Sign-in Required';
    }
  }

  static IconData _iconForStage(PaymentReturnStage stage) {
    switch (stage) {
      case PaymentReturnStage.loading:
        return Icons.hourglass_top;
      case PaymentReturnStage.pending:
        return Icons.schedule;
      case PaymentReturnStage.failed:
        return Icons.error_outline;
      case PaymentReturnStage.invalid:
        return Icons.info_outline;
      case PaymentReturnStage.authRequired:
        return Icons.lock_outline;
    }
  }

  static Color _colorForStage(
    PaymentReturnStage stage,
    ColorScheme colorScheme,
  ) {
    switch (stage) {
      case PaymentReturnStage.loading:
        return colorScheme.primary;
      case PaymentReturnStage.pending:
        return Colors.orange;
      case PaymentReturnStage.failed:
        return colorScheme.error;
      case PaymentReturnStage.invalid:
        return colorScheme.secondary;
      case PaymentReturnStage.authRequired:
        return colorScheme.primary;
    }
  }
}

class _PaymentReturnCallbackContext {
  final int holdId;
  final String merchantOrderId;

  const _PaymentReturnCallbackContext({
    required this.holdId,
    required this.merchantOrderId,
  });
}
