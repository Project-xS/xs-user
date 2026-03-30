import 'package:flutter/foundation.dart';
import 'package:xs_user/notification_service.dart';
import 'package:xs_user/phonepe_service.dart';

Future<void> initializeRuntimeServices() async {
  final isPhonePeInitialized = await PhonePeService.init();
  debugPrint('PhonePe initialized: $isPhonePeInitialized');
  await NotificationService().init();
}
