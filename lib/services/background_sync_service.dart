import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
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

    _addLog("Background service started", true);

    // Check every hour instead of waiting 24 hours
    // This handles service restarts much better
    Timer.periodic(const Duration(hours: 1), (timer) async {
      await _performBackgroundSync(service);
    });
  }

  static void _addLog(String message, bool success) {
    final storage = GetStorage();
    List<dynamic> logs = storage.read('sync_logs') ?? [];
    
    logs.insert(0, {
      'timestamp': DateTime.now().toIso8601String(),
      'success': success,
      'message': message,
    });

    if (logs.length > 50) logs = logs.sublist(0, 50);

    storage.write('sync_logs', logs);
  }

  static Future<void> _performBackgroundSync(ServiceInstance service, {int retryCount = 0}) async {
    try {
      // Use secure storage for sensitive data
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'auth_token');

      if (token == null) {
        _addLog("Background sync skipped: No auth token", false);
        return;
      }

      final storage = GetStorage();
      final userId = storage.read('user_id') as String?;

      if (userId == null) {
        _addLog("Background sync skipped: No user ID", false);
        return;
      }

      // Check if 24 hours have passed since last sync
      final lastSyncStr = storage.read('last_sync_time');
      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        final difference = DateTime.now().difference(lastSync);
        
        if (difference.inHours < 24) {
          debugPrint("Background sync: Too soon to sync (${difference.inHours}h since last)");
          return; 
        }
      }

      // Note: In background, we only FETCH data if permissions were already granted in UI
      // We do NOT call requestPermissions() here as it requires an Activity
      final healthService = HealthService();
      
      // Check permissions without requesting them
      final hasPerms = await healthService.hasPermissions();
      if (!hasPerms) {
        _addLog("Background sync skipped: Missing health permissions", false);
        return;
      }

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
        _addLog("Background sync successful", true);

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Health Sync",
            content: "Last sync: ${DateTime.now().toString().split('.').first}",
          );
        }
      } else {
        _addLog("Background sync: No new data to sync", true);
      }
    } catch (e) {
      _addLog("Background sync failed: ${e.toString()}", false);
      if (retryCount < 1) {
        Future.delayed(const Duration(minutes: 5), () {
          _performBackgroundSync(service, retryCount: 1);
        });
      }
    }
  }
}