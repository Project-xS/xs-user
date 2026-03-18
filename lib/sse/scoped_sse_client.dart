import 'dart:async';

import 'package:eventflux/eventflux.dart';

class ScopedSseClient {
  ScopedSseClient({
    required this.url,
    required this.headerBuilder,
    required this.onEvent,
    required this.onConnectionReady,
    required this.onReconnect,
    required this.onError,
    this.tag,
    this.maxReconnectDelaySeconds = 30,
  }) : _eventFlux = EventFlux.spawn();

  final String url;
  final Future<Map<String, String>> Function() headerBuilder;
  final void Function(EventFluxData event) onEvent;
  final Future<void> Function() onConnectionReady;
  final Future<void> Function() onReconnect;
  final void Function(Object error, [StackTrace? stackTrace]) onError;
  final String? tag;
  final int maxReconnectDelaySeconds;

  final EventFlux _eventFlux;

  StreamSubscription<EventFluxData>? _eventSub;
  Timer? _reconnectTimer;
  bool _active = false;
  bool _connected = false;
  int _reconnectAttempt = 0;

  bool get isActive => _active;
  bool get isConnected => _connected;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    _reconnectAttempt = 0;
    await _connect(isReconnect: false);
  }

  Future<void> stop() async {
    _active = false;
    _connected = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _eventFlux.disconnect();
  }

  Future<void> _connect({required bool isReconnect}) async {
    if (!_active) return;

    await _eventSub?.cancel();
    _eventSub = null;

    Map<String, String> headers;
    try {
      headers = await headerBuilder();
    } catch (e, st) {
      onError(e, st);
      _scheduleReconnect();
      return;
    }

    _eventFlux.connect(
      EventFluxConnectionType.get,
      url,
      header: headers,
      autoReconnect: false,
      tag: tag,
      onConnectionClose: () {
        _connected = false;
        _scheduleReconnect();
      },
      onSuccessCallback: (EventFluxResponse? response) {
        final stream = response?.stream;
        if (stream == null) {
          _connected = false;
          _scheduleReconnect();
          return;
        }

        _connected = true;
        _reconnectAttempt = 0;

        Future<void>(() async {
          try {
            if (isReconnect) {
              await onReconnect();
            } else {
              await onConnectionReady();
            }
          } catch (e, st) {
            onError(e, st);
          }
        });

        _eventSub = stream.listen(
          onEvent,
          onError: (Object e, StackTrace st) {
            _connected = false;
            onError(e, st);
            _scheduleReconnect();
          },
          onDone: () {
            _connected = false;
            _scheduleReconnect();
          },
          cancelOnError: false,
        );
      },
      onError: (EventFluxException exception) {
        _connected = false;
        onError(exception);
        _scheduleReconnect();
      },
    );
  }

  void _scheduleReconnect() {
    if (!_active) return;
    if (_reconnectTimer?.isActive ?? false) return;

    final attempt = _reconnectAttempt;
    _reconnectAttempt += 1;

    final delaySeconds = _computeBackoffSeconds(attempt);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _connect(isReconnect: true);
    });
  }

  int _computeBackoffSeconds(int attempt) {
    // 1,2,4,8,... up to configured max.
    final exponential = 1 << attempt;
    if (exponential > maxReconnectDelaySeconds) {
      return maxReconnectDelaySeconds;
    }
    return exponential;
  }
}
