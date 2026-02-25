import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/network_buffer.dart';

class OrderProvider extends ChangeNotifier {
  OrderResponse? _orderResponse;
  String? _error;
  bool _isLoading = false;

  OrderResponse? get orderResponse => _orderResponse;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> fetchOrders({bool force = false}) async {
    if (_isLoading) return;

    if (!force && _orderResponse != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    Future.microtask(() => notifyListeners());

    try {
      final api = ApiService();

      final activeOrders = await api.getOrdersForCurrentUser();
      final pastOrders = await api.getPastOrders();

      final orderMap = <int, Order>{};
      for (final order in activeOrders.data) {
        orderMap[order.orderId] = order;
      }
      for (final order in pastOrders.data) {
        orderMap[order.orderId] = order;
      }

      final combinedOrders = orderMap.values.toList()
        ..sort((a, b) => b.orderId.compareTo(a.orderId));

      _orderResponse = OrderResponse(
        data: combinedOrders,
        error: activeOrders.error ?? pastOrders.error,
        status: activeOrders.status,
      );
    } on AuthException catch (authError) {
      _error = authError.message;
      debugPrint(
        'Authentication error while fetching orders: ${authError.code}',
      );
    } on NetworkException catch (e) {
      _error = 'No internet connection. Retrying...';
      debugPrint('Network error fetching orders. Adding to buffer...');
      NetworkBuffer().add('fetch_orders', () => fetchOrders(force: true));
      rethrow;
    } on ApiException catch (apiError) {
      _error = apiError.message;
      debugPrint('API error while fetching orders: ${apiError.statusCode}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearOrders() {
    _orderResponse = null;
    notifyListeners();
  }
}
