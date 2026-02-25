import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/network_buffer.dart';

class MenuProvider extends ChangeNotifier {
  final Map<int, List<Item>> _menuItems = {};
  final Map<int, DateTime> _lastFetchTimes = {};
  final Set<int> _loadingCanteens = {};
  Timer? _refreshTimer;
  int? _activeCanteenId;

  List<Item> getMenuItems(int canteenId) => _menuItems[canteenId] ?? [];
  bool isLoading(int canteenId) => _loadingCanteens.contains(canteenId);

  void setActiveCanteen(int? canteenId) {
    _activeCanteenId = canteenId;
    if (canteenId != null) {
      _startRefreshTimer();
      fetchMenuItems(canteenId, force: true);
    } else {
      _stopRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_activeCanteenId != null) {
        fetchMenuItems(_activeCanteenId!, force: true);
      }
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopRefreshTimer();
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
    } on NetworkException catch (e) {
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
