import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/track_order_screen.dart';
import 'package:xs_user/order_provider.dart';
import 'package:provider/provider.dart';

enum OrderFilter { active, past, all }

class OrdersListScreen extends StatefulWidget {
  final bool showBackButton;
  final OrderFilter filter;

  const OrdersListScreen({
    super.key,
    this.showBackButton = false,
    this.filter = OrderFilter.all,
  });

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    await Provider.of<OrderProvider>(
      context,
      listen: false,
    ).fetchOrders(force: true);
  }

  String get _appBarTitle {
    switch (widget.filter) {
      case OrderFilter.active:
        return 'Active Orders';
      case OrderFilter.past:
        return 'Older Orders';
      case OrderFilter.all:
        return 'My Orders';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          _appBarTitle,
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading && orderProvider.orderResponse == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.error != null) {
            debugPrint('OrderProvider Error: ${orderProvider.orderResponse}');
            return Center(child: Text('Error: ${orderProvider.error}'));
          }

          if (orderProvider.orderResponse == null ||
              orderProvider.orderResponse!.data.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final List<Order> allOrders = orderProvider.orderResponse!.data;
          final List<Order> displayedOrders = allOrders.where((order) {
            switch (widget.filter) {
              case OrderFilter.active:
                return !order.orderStatus; // false means pending/active
              case OrderFilter.past:
                return order.orderStatus; // true means completed/past
              case OrderFilter.all:
                return true;
            }
          }).toList();

          if (displayedOrders.isEmpty) {
            return Center(
              child: Text(
                widget.filter == OrderFilter.active
                    ? 'No active orders.'
                    : widget.filter == OrderFilter.past
                    ? 'No previous orders.'
                    : 'No orders found.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayedOrders.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(
                context,
                orderData: displayedOrders[index],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, {required Order orderData}) {
    final String formattedDateTime;
    if (orderData.orderedAtMs == 0) {
      formattedDateTime = 'N/A';
    } else {
      final date = orderData.orderedAtDateTime;
      final formattedDate =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
      var hour = date.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour;
      final formattedTime =
          "${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm";
      formattedDateTime = "$formattedDate - $formattedTime";
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackOrderScreen(
              orderId: orderData.orderId,
              order: orderData,
              orderedAt: formattedDateTime,
            ),
          ),
        );
      },
      child: Card(
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '#${orderData.orderId}',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formattedDateTime,
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    orderData.canteenName,
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (orderData.deliverAt != null &&
                      orderData.deliverAt!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: const Color(0xFFFF7A3A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          orderData.deliverAt!,
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFFFF7A3A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: orderData.orderStatus
                          ? Colors.green
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      orderData.orderStatus ? 'Completed' : 'Pending',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₹${orderData.totalPrice.toString()}',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
