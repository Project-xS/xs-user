import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/order_screen_success.dart';
import 'dart:async';
import 'package:xs_user/order_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'upi';
  String _orderType = 'instant';
  String _selectedTimeBand = '11:00am - 12:00pm';
  final List<String> _timeBands = ['11:00am - 12:00pm', '12:00pm - 01:00pm'];

  // Hold state
  bool _isPlacingHold = false;
  bool _isConfirming = false;
  bool _isCancelling = false;
  int? _holdId;
  int? _expiresAt;
  bool _holdExpired = false;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  String? _orderError;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  bool get _inPaymentPhase => _holdId != null;

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_expiresAt == null) return;

    final expiresAtMs = _expiresAt! * 1000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = ((expiresAtMs - nowMs) / 1000).ceil();
    if (_secondsRemaining <= 0) {
      _secondsRemaining = 0;
      _holdExpired = true;
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _secondsRemaining = 0;
          _holdExpired = true;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  String _formatCountdown() {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _createHold() async {
    setState(() {
      _isPlacingHold = true;
      _orderError = null;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty || cart.totalAmount == 0) {
      setState(() {
        _orderError = 'Your cart is empty or the total amount is zero.';
        _isPlacingHold = false;
      });
      return;
    }

    final initializationService = InitializationService();
    if (initializationService.status == InitializationStatus.initializing) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Verifying..."),
              ],
            ),
          ),
        ),
      );

      final completer = Completer<void>();
      void listener() {
        if (initializationService.status != InitializationStatus.initializing) {
          completer.complete();
          initializationService.removeListener(listener);
        }
      }

      initializationService.addListener(listener);
      await completer.future;
      if (mounted) Navigator.of(context).pop();
    }
    if (initializationService.status == InitializationStatus.error) {
      setState(() {
        _orderError = 'Initialization failed. Please restart the app.';
        _isPlacingHold = false;
      });
      return;
    }

    final isSessionValid = await AuthService.isGoogleSessionValid();
    if (!isSessionValid) {
      setState(() {
        _orderError = 'Your Google session has expired. Please login again.';
        _isPlacingHold = false;
      });
      return;
    }
    if (cart.items.isEmpty) {
      setState(() {
        _isPlacingHold = false;
      });
      return;
    }
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final canteenId = cart.canteenId;

    if (canteenId == null) {
      setState(() {
        _orderError = 'Could not determine the canteen.';
        _isPlacingHold = false;
      });
      return;
    }

    try {
      await menuProvider.fetchMenuItems(canteenId, force: true);

      for (final cartItem in cart.items.values) {
        final menuItem = menuProvider
            .getMenuItems(canteenId)
            .firstWhere((item) => item.id.toString() == cartItem.id);
        if (!menuItem.isAvailable ||
            (menuItem.stock != -1 && menuItem.stock < cartItem.quantity)) {
          setState(() {
            _orderError =
                '${menuItem.name} is out of stock or chosen quantity is not available.';
            _isPlacingHold = false;
          });
          return;
        }
      }

      final itemIds = cart.items.values
          .expand(
            (item) => List.generate(item.quantity, (_) => int.parse(item.id)),
          )
          .toList();

      final deliverAt = _orderType == 'preorder' ? _selectedTimeBand : null;

      final response = await ApiService().createHold(itemIds, deliverAt);
      if (response.status == 'ok' && response.holdId != null) {
        setState(() {
          _holdId = response.holdId;
          _expiresAt = response.expiresAt;
          _holdExpired = false;
        });
        _startCountdown();
      } else {
        setState(() {
          _orderError = response.error ?? 'Failed to reserve items.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _orderError = e.message;
      });
    } on ApiException catch (_) {
      setState(() {
        _orderError = 'Failed to reserve items. Please try again.';
      });
    } catch (_) {
      setState(() {
        _orderError = 'Something went wrong. Please try again.';
      });
    } finally {
      setState(() {
        _isPlacingHold = false;
      });
    }
  }

  Future<void> _confirmHold() async {
    if (_holdId == null || _holdExpired) return;

    setState(() {
      _isConfirming = true;
      _orderError = null;
    });

    try {
      final response = await ApiService().confirmHold(_holdId!);
      if (response.status == 'ok' && response.orderId != null) {
        _countdownTimer?.cancel();
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.clear();
        if (!mounted) return;
        Provider.of<OrderProvider>(
          context,
          listen: false,
        ).fetchOrders(force: true);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OrderSuccessScreen(orderId: response.orderId!),
          ),
          (route) => false,
        );
      } else {
        final errorMsg = response.error ?? 'Failed to confirm order.';
        if (errorMsg.toLowerCase().contains('expired')) {
          setState(() {
            _holdExpired = true;
            _countdownTimer?.cancel();
            _orderError = 'Your reservation expired. Please try again.';
          });
        } else {
          setState(() {
            _orderError = errorMsg;
          });
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _orderError = e.message;
      });
    } on ApiException catch (_) {
      setState(() {
        _orderError = 'Failed to confirm order. Please try again.';
      });
    } catch (_) {
      setState(() {
        _orderError = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  Future<void> _cancelHold() async {
    if (_holdId == null) return;

    setState(() {
      _isCancelling = true;
      _orderError = null;
    });

    try {
      await ApiService().cancelHold(_holdId!);
    } on AuthException catch (e) {
      setState(() {
        _orderError = e.message;
      });
    } catch (_) {
      // Even if cancel fails server-side, reset local state — the hold will
      // expire automatically after 5 minutes anyway.
    } finally {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _holdId = null;
          _expiresAt = null;
          _holdExpired = false;
          _secondsRemaining = 0;
          _isCancelling = false;
        });
      }
    }
  }

  void _resetHoldState() {
    _countdownTimer?.cancel();
    setState(() {
      _holdId = null;
      _expiresAt = null;
      _holdExpired = false;
      _secondsRemaining = 0;
      _orderError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_inPaymentPhase,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _inPaymentPhase) {
          _showCancelConfirmDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              if (_inPaymentPhase) {
                _showCancelConfirmDialog();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _inPaymentPhase ? 'Confirm Payment' : 'Checkout',
            style: GoogleFonts.montserrat(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _inPaymentPhase ? _buildPaymentPhase() : _buildCheckoutPhase(),
      ),
    );
  }

  void _showCancelConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Reservation?'),
        content: const Text(
          'This will release your reserved items and restore stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancelHold();
            },
            child: Text(
              'Cancel Reservation',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 1: Checkout (pick time, payment method, review) ──

  Widget _buildCheckoutPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            context,
            title: 'Pickup Time',
            child: Column(
              children: [
                RadioListTile(
                  title: Text(
                    'Instant',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  value: 'instant',
                  groupValue: _orderType,
                  onChanged: (value) {
                    setState(() {
                      _orderType = value.toString();
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                RadioListTile(
                  title: Text(
                    'Preorder',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  value: 'preorder',
                  groupValue: _orderType,
                  onChanged: (value) {
                    setState(() {
                      _orderType = value.toString();
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                if (_orderType == 'preorder')
                  DropdownButton<String>(
                    value: _selectedTimeBand,
                    focusColor: Colors.transparent,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTimeBand = newValue!;
                      });
                    },
                    items: _timeBands.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.titleMedium?.color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context,
            title: 'Payment Method',
            child: Column(
              children: [
                RadioListTile(
                  title: Text(
                    'UPI',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  value: 'upi',
                  groupValue: _paymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value.toString();
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                RadioListTile(
                  title: Text(
                    'Card',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  value: 'card',
                  groupValue: _paymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value.toString();
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildOrderSummaryCard(),
          const SizedBox(height: 32),
          if (_orderError != null) _buildErrorBanner(),
          ElevatedButton(
            onPressed: _isPlacingHold ? null : _createHold,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isPlacingHold
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text(
                    'Reserve & Pay',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Phase 2: Payment with countdown ──

  Widget _buildPaymentPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Countdown timer
          _buildSectionCard(
            context,
            title: 'Complete Payment',
            child: Column(
              children: [
                Text(
                  _holdExpired ? 'Reservation Expired' : 'Time Remaining',
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCountdown(),
                  style: GoogleFonts.montserrat(
                    color: _holdExpired || _secondsRemaining < 60
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (!_holdExpired)
                  Text(
                    'Your items are reserved. Complete payment to confirm your order.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                if (_holdExpired)
                  Text(
                    'Your reservation expired. Please try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildOrderSummaryCard(),
          const SizedBox(height: 24),
          if (_orderError != null) _buildErrorBanner(),
          // Confirm button
          ElevatedButton(
            onPressed: (_isConfirming || _holdExpired) ? null : _confirmHold,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              disabledBackgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(100),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isConfirming
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text(
                    _holdExpired ? 'Reservation Expired' : 'Confirm Payment',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // Cancel / Try Again
          if (_holdExpired)
            OutlinedButton(
              onPressed: _resetHoldState,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.montserrat(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isCancelling
                  ? null
                  : () => _showCancelConfirmDialog(),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Cancel Reservation',
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  // ── Shared widgets ──

  Widget _buildOrderSummaryCard() {
    return _buildSectionCard(
      context,
      title: 'Order Summary',
      child: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items.values.toList()[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.name}  x${item.quantity}',
                          style: GoogleFonts.montserrat(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 32,
              ),
              _buildPriceRow(
                'Total',
                '₹${cart.totalAmount.toStringAsFixed(2)}',
                context,
                isTotal: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        _orderError!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String title,
    String price,
    BuildContext context, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            color: isTotal
                ? Theme.of(context).textTheme.titleLarge?.color
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          price,
          style: GoogleFonts.montserrat(
            color: isTotal
                ? Theme.of(context).textTheme.titleLarge?.color
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
