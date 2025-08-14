import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/models.dart';

class TrackOrderScreen extends StatefulWidget {
  final int orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  late Future<OrderData> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = ApiService().getOrderById(widget.orderId);
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
          'Track Order',
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<OrderData>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final orderData = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: #${orderData.orderId}',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimated Arrival: ${orderData.deliverAt}',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Order Summary',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orderData.items.length,
                    itemBuilder: (context, index) {
                      final item = orderData.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${item.quantity}x ${item.name}',
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price',
                        style: GoogleFonts.montserrat(
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${orderData.totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildStatusStep(context, title: 'Order Placed', isCompleted: true),
                  if (orderData.deliverAt == 'Instant')
                    _buildStatusStep(context, title: 'Ready to collect', isCompleted: true, isActive: true)
                  else
                    _buildStatusStep(context, title: 'Yet to be delivered', isCompleted: true, isActive: true),
                  _buildStatusStep(context, title: 'Delivered', isCompleted: false),
                ],
              ),
            );
          } else {
            return const Center(child: Text('No order data found.'));
          }
        },
      ),
    );
  }

  Widget _buildStatusStep(BuildContext context, {
    required String title,
    bool isCompleted = false,
    bool isActive = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle,
              color: isCompleted || isActive ? const Color(0xFFFF7A3A) : Theme.of(context).textTheme.bodyMedium?.color,
              size: 30,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  color: isActive || isCompleted ? Theme.of(context).textTheme.titleLarge?.color : Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        if (title != 'Delivered')
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Container(
              width: 2,
              height: 30,
              color: isCompleted ? const Color(0xFFFF7A3A) : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
      ],
    );
  }
}