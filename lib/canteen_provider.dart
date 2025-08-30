import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/models.dart';

class CanteenProvider extends ChangeNotifier {
  List<Canteen> _canteens = [];
  DateTime? _lastFetchTime;
  bool _isLoading = false;

  List<Canteen> get canteens => _canteens;
  bool get isLoading => _isLoading;

  Future<void> fetchCanteens({bool force = false}) async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (!force &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < const Duration(minutes: 5)) {
      return;
    }

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      _canteens = await ApiService().getActiveCanteens();
      _lastFetchTime = now;
      for (var canteen in _canteens) {
        MenuProvider().fetchMenuItems(canteen.id, force: true);
      }
    } catch (e) {
      debugPrint('Error fetching canteens: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
