import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/models.dart';

class MenuProvider extends ChangeNotifier {
  final Map<int, List<Item>> _menuItems = {};
  final Map<int, DateTime> _lastFetchTimes = {};
  bool _isLoading = false;

  List<Item> getMenuItems(int canteenId) => _menuItems[canteenId] ?? [];
  bool get isLoading => _isLoading;

  Future<void> fetchMenuItems(int canteenId, {bool force = false}) async {
    if (_isLoading) return;

    final now = DateTime.now();
    final lastFetchTime = _lastFetchTimes[canteenId];

    if (!force &&
        lastFetchTime != null &&
        now.difference(lastFetchTime) < const Duration(minutes: 1, seconds: 30)) {
      return;
    }

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      _menuItems[canteenId] = await ApiService().getItemsByCanteenId(canteenId);
      _lastFetchTimes[canteenId] = now;
    } catch (e) {
      debugPrint('Error fetching menu items for canteen $canteenId: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
