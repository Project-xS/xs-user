import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/orders_list_screen.dart';
import 'dart:ui';
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

  bool _isPlacingOrder = false;
  bool _orderPlaced = false;
  String? _orderError;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isPlacingOrder = true;
      _orderError = null;
    });

    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty || cart.totalAmount == 0) {
      setState(() {
        _orderError = 'Your cart is empty or the total amount is zero.';
        _isPlacingOrder = false;
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
      if(mounted) Navigator.of(context).pop();
    }
    if (initializationService.status == InitializationStatus.error) {
       setState(() {
        _orderError = 'Initialization failed. Please restart the app.';
        _isPlacingOrder = false;
      });
      return;
    }

    final bool isSessionValid = await AuthService.isGoogleSessionValid();
    if (isSessionValid == false) {
      setState(() {
        _orderError = 'Your Google session has expired. Please login again.';
        _isPlacingOrder = false;
      });
      return;
    }
    if (cart.items.isEmpty) {
       setState(() {
        _isPlacingOrder = false;
      });
      return;
    }
    bool? validsession = await AuthService.isGoogleSessionValid();
    if (validsession == false) {
      setState(() {
        _orderError = 'You are not signed in. Please sign in to place an order.';
        _isPlacingOrder = false;
      });
      return;
    }
    final menuProvider = Provider.of<MenuProvider>((mounted)?context:context, listen: false);
    final canteenId = cart.canteenId;

    if (canteenId == null) {
      setState(() {
        _orderError = 'Could not determine the canteen.';
        _isPlacingOrder = false;
      });
      return;
    }

    try {
      await menuProvider.fetchMenuItems(canteenId, force: true);

      for (final cartItem in cart.items.values) {
        final menuItem = menuProvider.getMenuItems(canteenId).firstWhere((item) => item.id.toString() == cartItem.id);
        if (!menuItem.isAvailable || (menuItem.stock != -1 && menuItem.stock < cartItem.quantity)) {
          setState(() {
            _orderError = '${menuItem.name} is out of stock or chosen quantity is not available.';
            _isPlacingOrder = false;
          });
          return;
        }
      }

      final itemIds = cart.items.values.expand((item) {
        return List.generate(item.quantity, (_) => int.parse(item.id));
      }).toList();

      final deliverAt = _orderType == 'preorder' ? _selectedTimeBand : "11:00am - 12:00pm";
      const userId = 1;

      final response = await ApiService().createOrder(userId, itemIds, deliverAt);
      if (response.status == 'ok') {
        setState(() {
          _orderPlaced = true;
        });
        _confettiController.play();
        cart.clear();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return PopScope(
              canPop: false,
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      color: Colors.black.withAlpha((255 * 0.5).round()),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary,
                            Colors.pink,
                            Colors.orange,
                            Colors.purple
                          ],
                        ),
                        Text(
                          'Order Placed Successfully!',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
        Timer(const Duration(seconds: 5), () {
          Navigator.of(context).pop();
          Provider.of<OrderProvider>(context, listen: false).fetchOrders(userId, force: true);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OrdersListScreen(showBackButton: true),
            ),
            (route) => false,
          );
        });
      } else {
        setState(() {
          _orderError = response.error ?? 'Failed to place order';
        });
      }
    } catch (e) {
      setState(() {
        _orderError = 'Failed to place order: $e';
      });
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
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
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).iconTheme.color),
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
                    title: Text('Instant', style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
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
                    title: Text('Preorder', style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
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
                      style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTimeBand = newValue!;
                        });
                      },
                      items: _timeBands.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
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
                    title: Text('UPI', style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
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
                    title: Text('Card', style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
                    value: 'card',
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _paymentMethod = value.toString();
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  // RadioListTile(
                  //   title: Text('Cash on Delivery', style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color)),
                  //   value: 'cod',
                  //   groupValue: _paymentMethod,
                  //   onChanged: (value) {
                  //     setState(() {
                  //       _paymentMethod = value.toString();
                  //     });
                  //   },
                  //   activeColor: Theme.of(context).primaryColor,
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
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
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // _buildPriceRow('Subtotal', '₹${cart.totalAmount.toStringAsFixed(2)}', context),
                      // const SizedBox(height: 8),
                      // _buildPriceRow('Delivery Fee', '₹2.00', context),
                      Divider(color: Theme.of(context).textTheme.bodyMedium?.color, height: 32),
                      _buildPriceRow('Total', '₹${cart.totalAmount.toStringAsFixed(2)}', context, isTotal: true),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            if (_orderError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _orderError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_orderPlaced)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: Column(
                    children: [
                      ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).colorScheme.secondary,
                          Colors.pink,
                          Colors.orange,
                          Colors.purple
                        ],
                      ),
                      Text(
                        'Order Placed Successfully!',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _isPlacingOrder ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isPlacingOrder
                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text(
                      'Place Order',
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required Widget child}) {
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

  Widget _buildPriceRow(String title, String price, BuildContext context, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            color: isTotal ? Theme.of(context).textTheme.titleLarge?.color : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          price,
          style: GoogleFonts.montserrat(
            color: isTotal ? Theme.of(context).textTheme.titleLarge?.color : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}