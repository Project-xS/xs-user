import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:web/web.dart' as web;

const bool _allowWebDebugEntry = bool.fromEnvironment(
  'ALLOW_WEB_DEBUG',
  defaultValue: false,
);

bool _isInstallPagePath(String path) {
  return path == '/' || path == '';
}

bool _shouldBypassForDebug() {
  return kDebugMode && _allowWebDebugEntry;
}

bool _isStandaloneMode() {
  final displayStandalone = web.window
      .matchMedia('(display-mode: standalone)')
      .matches;
  final navigator = web.window.navigator as JSObject;
  final standaloneValue = navigator.getProperty<JSBoolean?>('standalone'.toJS);
  final iosStandalone = standaloneValue?.toDart ?? false;
  return displayStandalone || iosStandalone;
}

Future<bool> enforcePwaEntryGate() async {
  if (_shouldBypassForDebug()) return true;
  if (_isStandaloneMode()) return true;
  final path = web.window.location.pathname;
  if (!_isInstallPagePath(path)) {
    web.window.location.replace('/');
  }
  return false;
}
