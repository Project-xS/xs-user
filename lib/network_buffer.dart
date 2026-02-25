import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Represents a request that failed due to network issues and is waiting for retry.
class BufferedRequest {
  final String id;
  final Future<void> Function() action;
  final DateTime timestamp;
  int retryCount;
  DateTime nextRetryTime;

  BufferedRequest({
    required this.id,
    required this.action,
  })  : timestamp = DateTime.now(),
        retryCount = 0,
        nextRetryTime = DateTime.now();

  void incrementRetry() {
    retryCount++;
    // Exponential backoff: 2s, 4s, 8s, 16s, 32s... up to a max of 1 minute
    final seconds = min(pow(2, retryCount).toInt(), 60);
    nextRetryTime = DateTime.now().add(Duration(seconds: seconds));
  }
}

class NetworkBuffer extends ChangeNotifier {
  static final NetworkBuffer _instance = NetworkBuffer._internal();
  factory NetworkBuffer() => _instance;
  NetworkBuffer._internal() {
    _initConnectivity();
    _startRetryTimer();
  }

  final List<BufferedRequest> _queue = [];
  bool _isProcessing = false;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  Timer? _retryTimer;

  List<BufferedRequest> get queue => List.unmodifiable(_queue);
  bool get isProcessing => _isProcessing;
  bool get hasInternet => _connectionStatus != ConnectivityResult.none;

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check if we have ANY valid connection in the list
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _connectionStatus = hasConnection ? results.first : ConnectivityResult.none;
      
      debugPrint('NetworkBuffer: Connection changed. Status: $_connectionStatus');
      
      if (hasConnection) {
        debugPrint('NetworkBuffer: Internet restored. Resetting backoffs and processing...');
        for (var req in _queue) {
          req.nextRetryTime = DateTime.now();
        }
        processQueue();
      }
      
      // CRITICAL: Tell the UI that 'hasInternet' has changed!
      notifyListeners();
    });
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    // Check every second if any request is ready for its next retry
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_queue.isNotEmpty && hasInternet && !_isProcessing) {
        final now = DateTime.now();
        final readyToRetry = _queue.any((req) => now.isAfter(req.nextRetryTime));
        if (readyToRetry) {
          processQueue();
        }
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  /// Adds a request to the buffer. 
  void add(String id, Future<void> Function() action) {
    // Check if it's already in the queue
    final exists = _queue.any((req) => req.id == id);
    if (!exists) {
      _queue.add(BufferedRequest(id: id, action: action));
      notifyListeners();
    }
    
    if (hasInternet) {
      processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;
    notifyListeners();

    final now = DateTime.now();
    // Only process items whose backoff time has passed
    final List<BufferedRequest> toProcess = _queue
        .where((req) => now.isAfter(req.nextRetryTime))
        .toList();

    debugPrint('NetworkBuffer: Attempting to process ${toProcess.length} ready requests');

    for (var request in toProcess) {
      if (!hasInternet) break;

      try {
        await request.action();
        // SUCCESS: Remove from the real queue
        _queue.removeWhere((req) => req.id == request.id);
        debugPrint('NetworkBuffer: SUCCESS for ${request.id}. Stack reduced to ${_queue.length}');
      } catch (e) {
        // FAIL: Keep in queue and increase wait time (Exponential Backoff)
        request.incrementRetry();
        debugPrint('NetworkBuffer: FAIL for ${request.id}. Next retry in ${request.nextRetryTime.difference(DateTime.now()).inSeconds}s');
      }
      notifyListeners();
    }

    _isProcessing = false;
    notifyListeners();
  }

  void clear() {
    _queue.clear();
    notifyListeners();
  }
}
