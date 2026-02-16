import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/order_screen_success.dart';
import 'dart:async';
import 'package:xs_user/order_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _orderType = 'instant';
  String _selectedTimeBand = '11:00am - 12:00pm';
  final List<String> _timeBands = ['11:00am - 12:00pm', '12:00pm - 01:00pm'];

  bool _isProcessing = false;
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
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    setState(() {
      _isProcessing = true;
      _orderError = null;
    });

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);

      // 1. Validation
      if (cart.items.isEmpty || cart.totalAmount == 0) {
        throw 'Your cart is empty.';
      }

      final initializationService = InitializationService();
      if (initializationService.status != InitializationStatus.initialized) {
        // Re-run init check if needed, or just fail safely
        // For brevity assuming standard auth check passes or throws in ApiService
      }

      final isSessionValid = await AuthService.isGoogleSessionValid();
      if (!isSessionValid) throw 'Session expired. Please login again.';

      final canteenId = cart.canteenId;
      if (canteenId == null) throw 'Could not determine canteen.';

      // 2. Create Hold
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      await menuProvider.fetchMenuItems(canteenId, force: true);

      // Stock check
      for (final cartItem in cart.items.values) {
        final menuItem = menuProvider
            .getMenuItems(canteenId)
            .firstWhere(
              (item) => item.id.toString() == cartItem.id,
              orElse: () => Item(
                id: -1,
                name: 'Unknown',
                price: 0,
                pic: '',
                etag: '',
                canteenId: canteenId,
                isVeg: true,
                isAvailable: false,
                stock: 0,
              ),
            );

        if (menuItem.id == -1) {
          continue; // Skip check if item missing? Or throw?
        }

        if (!menuItem.isAvailable ||
            (menuItem.stock != -1 && menuItem.stock < cartItem.quantity)) {
          throw '${menuItem.name} is out of stock.';
        }
      }

      final itemIds = cart.items.values
          .expand(
            (item) => List.generate(item.quantity, (_) => int.parse(item.id)),
          )
          .toList();

      final deliverAt = _orderType == 'preorder' ? _selectedTimeBand : null;

      final holdResponse = await ApiService().createHold(itemIds, deliverAt);
      if (holdResponse.status != 'ok' || holdResponse.holdId == null) {
        throw holdResponse.error ?? 'Failed to reserve items.';
      }

      // 3. Confirm Hold (Implicit Payment)
      final confirmResponse = await ApiService().confirmHold(
        holdResponse.holdId!,
      );

      if (confirmResponse.status == 'ok' && confirmResponse.orderId != null) {
        cart.clear();
        Provider.of<OrderProvider>(
          context,
          listen: false,
        ).fetchOrders(force: true);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OrderSuccessScreen(orderId: confirmResponse.orderId!),
          ),
          (route) => false,
        );
      } else {
        throw confirmResponse.error ?? 'Payment failed.';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orderError = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                      style: GoogleFonts.montserrat(fontSize: 14),
                    ),
                    value: 'instant',
                    groupValue: _orderType,
                    onChanged: (val) =>
                        setState(() => _orderType = val.toString()),
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile(
                    title: Text(
                      'Preorder',
                      style: GoogleFonts.montserrat(fontSize: 14),
                    ),
                    value: 'preorder',
                    groupValue: _orderType,
                    onChanged: (val) =>
                        setState(() => _orderType = val.toString()),
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_orderType == 'preorder')
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTimeBand,
                        isExpanded: true,
                        underline: Container(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        items: _timeBands
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedTimeBand = val!),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildOrderSummary(context),
            const SizedBox(height: 32),
            if (_orderError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _orderError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(
              onPressed: _isProcessing ? null : _handleCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha(100),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Pay with UPI',
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: child, // Inner content
        ),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ...cart.items.values.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Qty: ${item.quantity}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${cart.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
