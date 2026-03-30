import 'dart:html' as html;

bool _isStandaloneMode() {
  final displayStandalone = html.window
      .matchMedia('(display-mode: standalone)')
      .matches;
  final navigatorStandalone =
      (html.window.navigator as dynamic).standalone as bool? ?? false;
  return displayStandalone || navigatorStandalone;
}

Future<bool> enforcePwaEntryGate() async {
  if (_isStandaloneMode()) return true;
  html.window.location.replace('/');
  return false;
}
