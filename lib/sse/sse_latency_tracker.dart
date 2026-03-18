class SseLatencyTracker {
  SseLatencyTracker({
    this.thresholdMs = 5000,
    this.requiredConsecutiveBreaches = 3,
    this.maxSamples = 20,
    this.requiredConsecutiveRecoveries = 2,
  });

  final int thresholdMs;
  final int requiredConsecutiveBreaches;
  final int maxSamples;
  final int requiredConsecutiveRecoveries;

  final List<int> _recentSamplesMs = <int>[];

  int _consecutiveBreaches = 0;
  int _consecutiveRecoveries = 0;
  int? _latestSampleMs;
  bool _isSlow = false;

  bool get isSlow => _isSlow;
  int? get latestSampleMs => _latestSampleMs;
  int get consecutiveBreaches => _consecutiveBreaches;
  List<int> get recentSamplesMs => List<int>.unmodifiable(_recentSamplesMs);

  void recordFromEventId(String eventId, {int? deviceNowMs}) {
    final parsed = int.tryParse(eventId.trim());
    if (parsed == null) return;
    recordSample(serverPublishedEpochMs: parsed, deviceNowMs: deviceNowMs);
  }

  void recordSample({required int serverPublishedEpochMs, int? deviceNowMs}) {
    final nowMs = deviceNowMs ?? DateTime.now().millisecondsSinceEpoch;

    // SSE id is server publish epoch; observed lag approximates clock skew + transit.
    final sample = nowMs - serverPublishedEpochMs;
    _latestSampleMs = sample;

    _recentSamplesMs.add(sample);
    if (_recentSamplesMs.length > maxSamples) {
      _recentSamplesMs.removeAt(0);
    }

    final breach = sample > thresholdMs;
    if (breach) {
      _consecutiveBreaches += 1;
      _consecutiveRecoveries = 0;
      if (_consecutiveBreaches >= requiredConsecutiveBreaches) {
        _isSlow = true;
      }
      return;
    }

    _consecutiveBreaches = 0;
    if (_isSlow) {
      _consecutiveRecoveries += 1;
      if (_consecutiveRecoveries >= requiredConsecutiveRecoveries) {
        _isSlow = false;
        _consecutiveRecoveries = 0;
      }
    }
  }

  void reset() {
    _recentSamplesMs.clear();
    _consecutiveBreaches = 0;
    _consecutiveRecoveries = 0;
    _latestSampleMs = null;
    _isSlow = false;
  }
}
