import 'runtime_services_mobile.dart'
    if (dart.library.html) 'runtime_services_web.dart'
    as impl;

Future<void> initializeRuntimeServices() => impl.initializeRuntimeServices();
