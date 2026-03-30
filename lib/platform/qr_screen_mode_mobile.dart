import 'package:screen_brightness/screen_brightness.dart';

Future<void> activateQrScreenMode() async {
  try {
    await ScreenBrightness().setScreenBrightness(1.0);
  } catch (_) {
    // Keep QR flow usable even if brightness APIs are unavailable.
  }
}

Future<void> deactivateQrScreenMode() async {
  try {
    await ScreenBrightness().resetScreenBrightness();
  } catch (_) {
    // Ignore cleanup failures.
  }
}

Future<void> requestQrFullscreen() async {
  // No-op on mobile.
}
