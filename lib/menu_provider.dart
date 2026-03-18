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

class MenuProvider extends ChangeNotifier {
  final Map<int, List<Item>> _menuItems = {};
  final Map<int, DateTime> _lastFetchTimes = {};
  final Set<int> _loadingCanteens = {};

  int? _activeCanteenId;
  ScopedSseClient? _inventorySseClient;
  final SseLatencyTracker _inventoryLatencyTracker = SseLatencyTracker();

  List<Item> getMenuItems(int canteenId) => _menuItems[canteenId] ?? [];
  bool isLoading(int canteenId) => _loadingCanteens.contains(canteenId);
  int? get activeCanteenId => _activeCanteenId;
  bool get hasSlowInventoryConnection => _inventoryLatencyTracker.isSlow;
  int? get inventorySkewPlusTransitMs => _inventoryLatencyTracker.latestSampleMs;

  void setActiveCanteen(int? canteenId) {
    if (_activeCanteenId == canteenId) return;

    final previous = _activeCanteenId;
    _activeCanteenId = canteenId;

    if (previous != null && previous != canteenId) {
      unawaited(_stopInventoryUpdates(resetLatency: true));
    }

    if (canteenId == null) {
      unawaited(_stopInventoryUpdates(resetLatency: true));
      return;
    }

    unawaited(fetchMenuItems(canteenId, force: true));
    unawaited(_startInventoryUpdates(canteenId));
  }

  Future<void> _startInventoryUpdates(int canteenId) async {
    await _stopInventoryUpdates(resetLatency: false);
    _inventoryLatencyTracker.reset();
    notifyListeners();

    final client = ScopedSseClient(
      url: '${ApiService.baseUrl}/menu/events/inventory/$canteenId',
      headerBuilder: _buildSseHeaders,
      tag: 'menu-inventory-$canteenId',
      onConnectionReady: () async {
        // No-op on first connect; initial state comes from REST.
      },
      onReconnect: () async {
        // Heal missed updates after transient disconnects.
        await fetchMenuItems(canteenId, force: true);
      },
      onEvent: (event) => _handleInventorySseEvent(canteenId, event),
      onError: (error, [stackTrace]) {
        debugPrint('Inventory SSE error for canteen $canteenId: $error');
      },
    );

    _inventorySseClient = client;
    await client.start();
  }

  Future<void> _stopInventoryUpdates({required bool resetLatency}) async {
    final existing = _inventorySseClient;
    _inventorySseClient = null;
    if (existing != null) {
      await existing.stop();
    }

    if (resetLatency) {
      _inventoryLatencyTracker.reset();
      notifyListeners();
    }
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

  void _handleInventorySseEvent(int canteenId, EventFluxData event) {
    if (_activeCanteenId != canteenId) return;

    final wasSlow = _inventoryLatencyTracker.isSlow;
    if (event.id.trim().isNotEmpty) {
      _inventoryLatencyTracker.recordFromEventId(event.id);
    }

    final nowSlow = _inventoryLatencyTracker.isSlow;
    if (wasSlow != nowSlow) {
      notifyListeners();
    }

    final eventName = event.event.trim();
    if (eventName == 'status') {
      return;
    }

    if (eventName != 'inventory_update') {
      debugPrint('Ignoring unknown inventory SSE event: $eventName');
      return;
    }

    final payloadString = event.data.trim();
    if (payloadString.isEmpty) return;

    try {
      final decoded = jsonDecode(payloadString);
      if (decoded is! Map<String, dynamic>) return;
      final items = decoded['items'];
      if (items is! List) return;

      final updates = <_InventoryAbsoluteUpdate>[];
      for (final dynamic raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final itemId = raw['item_id'];
        final stock = raw['stock'];
        final isAvailable = raw['is_available'];
        final price = raw['price'];

        if (itemId is! num ||
            stock is! num ||
            isAvailable is! bool ||
            price is! num) {
          continue;
        }

        updates.add(
          _InventoryAbsoluteUpdate(
            itemId: itemId.toInt(),
            stock: stock.toInt(),
            isAvailable: isAvailable,
            price: price.toDouble(),
          ),
        );
      }

      if (updates.isEmpty) return;

      final allFound = _applyInventorySnapshot(canteenId, updates);
      if (!allFound) {
        unawaited(fetchMenuItems(canteenId, force: true));
      }
    } catch (e) {
      debugPrint('Failed parsing inventory SSE payload: $e');
    }
  }

  bool _applyInventorySnapshot(
    int canteenId,
    List<_InventoryAbsoluteUpdate> updates,
  ) {
    final currentList = _menuItems[canteenId];
    if (currentList == null || currentList.isEmpty) {
      return false;
    }

    var anyChanged = false;
    var allFound = true;

    for (final update in updates) {
      final index = currentList.indexWhere((item) => item.id == update.itemId);
      if (index < 0) {
        allFound = false;
        continue;
      }

      final existing = currentList[index];
      final updated = Item(
        id: existing.id,
        name: existing.name,
        description: existing.description,
        price: update.price,
        pic: existing.pic,
        etag: existing.etag,
        canteenId: existing.canteenId,
        isVeg: existing.isVeg,
        isAvailable: update.stock == -1 ? true : update.isAvailable,
        stock: update.stock,
      );

      if (updated != existing) {
        currentList[index] = updated;
        anyChanged = true;
      }
    }

    if (anyChanged) {
      notifyListeners();
    }
    return allFound;
  }

  @override
  void dispose() {
    unawaited(_stopInventoryUpdates(resetLatency: false));
    super.dispose();
  }

  Future<void> fetchMenuItems(int canteenId, {bool force = false}) async {
    if (_loadingCanteens.contains(canteenId)) return;

    final now = DateTime.now();
    final lastFetchTime = _lastFetchTimes[canteenId];

    if (!force &&
        lastFetchTime != null &&
        now.difference(lastFetchTime) <
            const Duration(minutes: 1, seconds: 30)) {
      return;
    }

    // Only show loading if we have NO items for this canteen yet
    final bool isInitialLoad = (_menuItems[canteenId] ?? []).isEmpty;
    if (isInitialLoad) {
      _loadingCanteens.add(canteenId);
      Future.microtask(() => notifyListeners());
    }

    try {
      final fetchedItems = await ApiService().getItemsByCanteenId(canteenId);
      _lastFetchTimes[canteenId] = now;

      if (isInitialLoad) {
        _menuItems[canteenId] = fetchedItems;
      } else {
        // MERGE LOGIC: Update existing items and add new ones
        final currentList = _menuItems[canteenId]!;
        for (var newItem in fetchedItems) {
          final index = currentList.indexWhere((item) => item.id == newItem.id);
          if (index != -1) {
            currentList[index] = newItem; // Update existing
          } else {
            currentList.add(newItem); // Add new
          }
        }
        // Sync removals (optional, but keeps data clean)
        currentList.removeWhere((old) => !fetchedItems.any((n) => n.id == old.id));
      }
      notifyListeners();
    } on AuthException {
      rethrow;
    } on NetworkException {
      debugPrint('Network error fetching menu for $canteenId. Adding to buffer...');
      NetworkBuffer().add('fetch_menu_$canteenId', () => fetchMenuItems(canteenId, force: true));
      rethrow;
    } catch (e) {
      debugPrint('Error fetching menu items for canteen $canteenId: $e');
    } finally {
      if (isInitialLoad) {
        _loadingCanteens.remove(canteenId);
        notifyListeners();
      }
    }
  }
}

class _InventoryAbsoluteUpdate {
  _InventoryAbsoluteUpdate({
    required this.itemId,
    required this.stock,
    required this.isAvailable,
    required this.price,
  });

  final int itemId;
  final int stock;
  final bool isAvailable;
  final double price;
}
