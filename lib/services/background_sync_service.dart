import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'health_service.dart';

@pragma('vm:entry-point')
class BackgroundSyncService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'health_sync_channel',
        initialNotificationTitle: 'Health Sync',
        initialNotificationContent: 'Syncing health data...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Ensure the plugin is registered for the background isolate
    DartPluginRegistrant.ensureInitialized();
    await GetStorage.init();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Periodic sync logic
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _performBackgroundSync(service);
    });
  }

  static Future<void> _performBackgroundSync(ServiceInstance service, {int retryCount = 0}) async {
    try {
      // Use secure storage for sensitive data
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'auth_token');

      if (token == null) return;

      final storage = GetStorage();
      final userId = storage.read('user_id') as String?;

      if (userId == null) return;

      // Note: In background, we only FETCH data if permissions were already granted in UI
      // We do NOT call requestPermissions() here as it requires an Activity
      final healthService = HealthService();
      
      // Check permissions without requesting them
      final hasPerms = await healthService.hasPermissions();
      if (!hasPerms) return;

      final payload = await healthService.fetchLatestSyncPayload();
      
      if (payload != null) {
        final dio = Dio(BaseOptions(
          baseUrl: 'https://orishub.com/api/',
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ));
        
        await dio.post('submissions/$userId', data: payload);
      }
    } catch (e) {
      if (retryCount < 1) {
        Future.delayed(const Duration(minutes: 5), () {
          _performBackgroundSync(service, retryCount: 1);
        });
      }
    }
  }
}