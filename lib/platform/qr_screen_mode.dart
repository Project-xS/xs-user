import 'qr_screen_mode_mobile.dart'
    if (dart.library.html) 'qr_screen_mode_web.dart'
    as impl;

Future<void> activateQrScreenMode() => impl.activateQrScreenMode();
Future<void> deactivateQrScreenMode() => impl.deactivateQrScreenMode();
Future<void> requestQrFullscreen() => impl.requestQrFullscreen();
