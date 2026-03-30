import 'dart:js_interop';
import 'package:web/web.dart' as web;

web.WakeLockSentinel? _wakeLockSentinel;

Future<void> activateQrScreenMode() async {
  try {
    _wakeLockSentinel = await web.window.navigator.wakeLock
        .request('screen')
        .toDart;
  } catch (_) {
    // Wake lock is best-effort only on web.
  }
}

Future<void> deactivateQrScreenMode() async {
  try {
    final sentinel = _wakeLockSentinel;
    if (sentinel != null) {
      await sentinel.release().toDart;
      _wakeLockSentinel = null;
    }
  } catch (_) {
    // Ignore release failures.
  }
}

Future<void> requestQrFullscreen() async {
  try {
    final element = web.document.documentElement;
    if (element == null) return;
    if (web.document.fullscreenElement != null) return;
    await element.requestFullscreen().toDart;
  } catch (_) {
    // Fullscreen might be rejected if not triggered from user gesture.
  }
}
