import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/network_buffer.dart';

class CanteenProvider extends ChangeNotifier {
  List<Canteen> _canteens = [];
  DateTime? _lastFetchTime;
  bool _isLoading = false;
  Timer? _refreshTimer;

  List<Canteen> get canteens => _canteens;
  List<Canteen> get sortedCanteens {
    final sorted = List<Canteen>.from(_canteens);
    sorted.sort((a, b) {
      if (a.isOpen != b.isOpen) {
        return (b.isOpen ? 1 : 0) - (a.isOpen ? 1 : 0);
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
  bool get isLoading => _isLoading;

  CanteenProvider() {
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1, seconds: 30), (timer) {
      fetchCanteens(force: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchCanteens({bool force = false}) async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (!force &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < const Duration(minutes: 1)) {
      return;
    }

    // Only show loading spinner if the list is completely empty
    final bool isInitialLoad = _canteens.isEmpty;
    if (isInitialLoad) {
      _isLoading = true;
      Future.microtask(() => notifyListeners());
    }

    try {
      final newCanteens = await ApiService().getActiveCanteens();
      _lastFetchTime = now;

      if (isInitialLoad) {
        _canteens = newCanteens;
      } else {
        // UPDATE EXISTING & ADD NEW (Merge Logic)
        for (var newCanteen in newCanteens) {
          final index = _canteens.indexWhere((c) => c.id == newCanteen.id);
          if (index != -1) {
            _canteens[index] = newCanteen; // Update existing
          } else {
            _canteens.add(newCanteen); // Add new
          }
        }
        // Remove canteens that are no longer in the server list
        _canteens.removeWhere((old) => !newCanteens.any((n) => n.id == old.id));
      }
      notifyListeners();
    } on AuthException {
      rethrow;
    } on NetworkException {
      debugPrint('Network error fetching canteens. Adding to buffer...');
      NetworkBuffer().add('fetch_canteens', () => fetchCanteens(force: true));
      rethrow;
    } catch (e) {
      debugPrint('Error fetching canteens: $e');
    } finally {
      if (isInitialLoad) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
