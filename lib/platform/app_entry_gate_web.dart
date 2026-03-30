import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

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
  if (_isStandaloneMode()) return true;
  web.window.location.replace('/');
  return false;
}
