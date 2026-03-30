import 'app_entry_gate_stub.dart'
    if (dart.library.html) 'app_entry_gate_web.dart'
    as impl;

Future<bool> enforcePwaEntryGate() => impl.enforcePwaEntryGate();
