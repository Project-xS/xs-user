import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
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
          'Your Cart',
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) => _buildCartItem(
                context: context,
                item: cart.items.values.toList()[i],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                _buildPriceRow('Subtotal', '₹${cart.totalAmount.toStringAsFixed(2)}', context),
                const SizedBox(height: 8),
                Divider(color: Theme.of(context).textTheme.bodyMedium?.color, height: 32),
                _buildPriceRow('Total', '₹${cart.totalAmount.toStringAsFixed(2)}', context, isTotal: true),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CheckoutScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Proceed to Checkout',
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
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required BuildContext context,
    required CartItem item,
  }) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              item.isVeg ? 'assets/veg.jpg' : 'assets/non_veg.jpg',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
            // item.hasImage
            //     ? Image.network(
            //         '${ApiService.baseUrl}/assets/item_${item.id}',
            //         width: 80,
            //         height: 80,
            //         fit: BoxFit.cover,
            //         errorBuilder: (context, error, stackTrace) {
            //           return Container(
            //             width: 80,
            //             height: 80,
            //             color: Colors.grey.withOpacity(0.1),
            //             child: Icon(
            //               Icons.fastfood,
            //               color: Theme.of(context).iconTheme.color,
            //               size: 40,
            //             ),
            //           );
            //         },
            //       )
            //     : Container(
            //         width: 80,
            //         height: 80,
            //         color: Colors.grey.withOpacity(0.1),
            //         child: Icon(
            //           Icons.fastfood,
            //           color: Theme.of(context).iconTheme.color,
            //           size: 40,
            //         ),
            //       ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.titleMedium?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.titleMedium?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  cart.removeSingleItem(item.id);
                },
                icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).iconTheme.color),
              ),
              Text(
                item.quantity.toString(),
                style: GoogleFonts.montserrat(
                  color: Theme.of(context).textTheme.titleMedium?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  cart.addItem(item.id, item.name, item.price, cart.canteenId!, item.hasImage, item.isVeg);
                },
                icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ],
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