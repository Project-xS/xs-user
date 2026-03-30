import 'dart:html' as html;

Object? _wakeLockSentinel;

Future<void> activateQrScreenMode() async {
  try {
    final wakeLock = (html.window.navigator as dynamic).wakeLock;
    if (wakeLock == null) return;
    _wakeLockSentinel = await wakeLock.request('screen') as Object?;
  } catch (_) {
    // Wake lock is best-effort only on web.
  }
}

Future<void> deactivateQrScreenMode() async {
  try {
    final sentinel = _wakeLockSentinel;
    if (sentinel != null) {
      await (sentinel as dynamic).release();
      _wakeLockSentinel = null;
    }
  } catch (_) {
    // Ignore release failures.
  }
}

Future<void> requestQrFullscreen() async {
  try {
    final element = html.document.documentElement;
    if (element == null) return;
    if (html.document.fullscreenElement != null) return;
    await element.requestFullscreen();
  } catch (_) {
    // Fullscreen might be rejected if not triggered from user gesture.
  }
}
