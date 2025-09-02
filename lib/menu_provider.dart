import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/models.dart';

class MenuProvider extends ChangeNotifier {
  final Map<int, List<Item>> _menuItems = {};
  final Map<int, DateTime> _lastFetchTimes = {};
  final Set<int> _loadingCanteens = {};

  List<Item> getMenuItems(int canteenId) => _menuItems[canteenId] ?? [];
  bool isLoading(int canteenId) => _loadingCanteens.contains(canteenId);

  Future<void> fetchMenuItems(int canteenId, {bool force = false}) async {
    if (_loadingCanteens.contains(canteenId)) return;

    final now = DateTime.now();
    final lastFetchTime = _lastFetchTimes[canteenId];

    if (!force &&
        lastFetchTime != null &&
        now.difference(lastFetchTime) < const Duration(minutes: 1, seconds: 30)) {
      return;
    }

    _loadingCanteens.add(canteenId);
    Future.microtask(() => notifyListeners());

    try {
      _menuItems[canteenId] = await ApiService().getItemsByCanteenId(canteenId);
      _lastFetchTimes[canteenId] = now;
    } catch (e) {
      debugPrint('Error fetching menu items for canteen $canteenId: $e');
    } finally {
      _loadingCanteens.remove(canteenId);
      notifyListeners();
    }
  }
}