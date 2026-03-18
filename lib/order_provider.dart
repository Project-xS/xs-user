import 'dart:async';
import 'dart:convert';

import 'package:eventflux/eventflux.dart';
import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/network_buffer.dart';
import 'package:xs_user/sse/scoped_sse_client.dart';
import 'package:xs_user/sse/sse_latency_tracker.dart';

class OrderProvider extends ChangeNotifier {
  OrderResponse? _orderResponse;
  String? _error;
  bool _isLoading = false;
  ScopedSseClient? _ordersSseClient;
  final SseLatencyTracker _orderLatencyTracker = SseLatencyTracker();

  OrderResponse? get orderResponse => _orderResponse;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get hasSlowOrderConnection => _orderLatencyTracker.isSlow;
  int? get orderSkewPlusTransitMs => _orderLatencyTracker.latestSampleMs;

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
    } on NetworkException {
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

  Future<void> startActiveOrderUpdates() async {
    if (_ordersSseClient != null) return;

    _orderLatencyTracker.reset();
    notifyListeners();

    final client = ScopedSseClient(
      url: '${ApiService.baseUrl}/users/events/orders',
      headerBuilder: _buildSseHeaders,
      tag: 'user-orders',
      onConnectionReady: () async {
        // Initial list is still sourced via REST.
      },
      onReconnect: () async {
        // Re-sync after temporary stream interruption.
        await fetchOrders(force: true);
      },
      onEvent: _handleOrderSseEvent,
      onError: (error, [stackTrace]) {
        debugPrint('Order SSE error: $error');
      },
    );

    _ordersSseClient = client;
    await client.start();
  }

  Future<void> stopActiveOrderUpdates() async {
    final existing = _ordersSseClient;
    _ordersSseClient = null;
    if (existing != null) {
      await existing.stop();
    }
    _orderLatencyTracker.reset();
    notifyListeners();
  }

  Future<Map<String, String>> _buildSseHeaders() async {
    final token = await AuthService.getValidIdToken();
    if (token == null) {
      throw AuthException('sign-in-required', 'Unable to fetch auth token.');
    }
    return <String, String>{
      'Accept': 'text/event-stream',
      'Authorization': 'Bearer $token',
    };
  }

  void _handleOrderSseEvent(EventFluxData event) {
    final eventName = event.event.trim().toLowerCase();
    final payloadString = event.data.trim();
    if (_isIgnorableKeepAliveEvent(eventName, payloadString)) {
      return;
    }

    final wasSlow = _orderLatencyTracker.isSlow;
    if (event.id.trim().isNotEmpty) {
      _orderLatencyTracker.recordFromEventId(event.id);
    }
    if (wasSlow != _orderLatencyTracker.isSlow) {
      notifyListeners();
    }

    if (eventName == 'status') {
      return;
    }

    if (eventName != 'user_order_update') {
      debugPrint('Ignoring unknown order SSE event: ${event.event.trim()}');
      return;
    }

    if (payloadString.isEmpty) return;

    try {
      final decoded = jsonDecode(payloadString);
      if (decoded is! Map<String, dynamic>) return;

      final rawOrderId = decoded['order_id'];
      final rawStatus = decoded['status'];
      if (rawOrderId is! num || rawStatus is! String) {
        return;
      }

      final applied = applyOrderStatusUpdate(
        rawOrderId.toInt(),
        rawStatus.toLowerCase(),
      );

      if (!applied) {
        unawaited(fetchOrders(force: true));
      }
    } catch (e) {
      debugPrint('Failed parsing user_order_update payload: $e');
    }
  }

  bool _isIgnorableKeepAliveEvent(String eventName, String payload) {
    if (eventName.isEmpty && payload.isEmpty) {
      return true;
    }
    if (eventName == 'keep-alive' || eventName == 'keepalive') {
      return true;
    }
    if (payload == 'keep-alive' || payload == '"keep-alive"') {
      return true;
    }
    if (payload == ': keep-alive' || payload == 'keep-alive ping') {
      return true;
    }
    return false;
  }

  bool applyOrderStatusUpdate(int orderId, String status) {
    final mappedStatus = _mapOrderStatus(status);
    if (mappedStatus == null) return false;

    final response = _orderResponse;
    if (response == null) {
      return false;
    }

    final index = response.data.indexWhere((order) => order.orderId == orderId);
    if (index < 0) {
      return false;
    }

    final existing = response.data[index];
    if (existing.orderStatus == mappedStatus) {
      return true;
    }

    final updatedOrder = Order(
      orderId: existing.orderId,
      orderStatus: mappedStatus,
      orderedAtMs: existing.orderedAtMs,
      totalPrice: existing.totalPrice,
      items: existing.items,
      deliverAt: existing.deliverAt,
      canteenName: existing.canteenName,
    );

    final updatedOrders = List<Order>.from(response.data);
    updatedOrders[index] = updatedOrder;
    updatedOrders.sort((a, b) => b.orderId.compareTo(a.orderId));

    _orderResponse = OrderResponse(
      data: updatedOrders,
      error: response.error,
      status: response.status,
    );
    notifyListeners();
    return true;
  }

  bool? _mapOrderStatus(String status) {
    switch (status) {
      case 'placed':
        return false;
      case 'delivered':
      case 'cancelled':
        return true;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    final existing = _ordersSseClient;
    _ordersSseClient = null;
    _orderLatencyTracker.reset();
    if (existing != null) {
      unawaited(existing.stop());
    }
    super.dispose();
  }
}
