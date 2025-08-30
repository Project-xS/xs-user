import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/models.dart';

class OrderProvider extends ChangeNotifier {
  OrderResponse? _orderResponse;
  String? _error;
  bool _isLoading = false;

  OrderResponse? get orderResponse => _orderResponse;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> fetchOrders(int userId, {bool force = false}) async {
    if (_isLoading) return;

    if (!force && _orderResponse != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    Future.microtask(() => notifyListeners());

    try {
      _orderResponse = await ApiService().getActiveOrders(userId: userId);
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
