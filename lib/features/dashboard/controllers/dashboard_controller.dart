import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../services/health_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class DashboardController extends GetxController {
  final _healthService = Get.find<HealthService>();
  final storage = Get.find<StorageService>();
  final _dio = Get.find<DioClient>();

  final steps = 0.obs;
  final isSyncing = false.obs;
  final lastSync = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    lastSync.value = storage.getLastSync();
  }

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    // Check and request permissions on startup if needed
    // Delay slightly to ensure Activity is attached
    await Future.delayed(const Duration(milliseconds: 500));
    await _handleHealthPermissions();
    await fetchLatestData();
    final token = await storage.getToken();

    debugPrint("Payload: $token");
    _startBackgroundServiceSafe();
  }

  Future<void> _handleHealthPermissions() async {
    final hasPermission = await _healthService.hasPermissions();

    if (!hasPermission) {
      // Use the unified request method in HealthService
      final granted = await _healthService.requestPermissions();
      if (!granted) {
        debugPrint("Health permission denied by user");
        return;
      }
    }
    debugPrint("Health permissions confirmed");
  }

  void _startBackgroundServiceSafe() async {
    try {
      final service = FlutterBackgroundService();
      if (!(await service.isRunning())) {
        await service.startService();
      }
    } catch (e) {
      debugPrint("Error starting background service: $e");
    }
  }

  Future<void> fetchLatestData() async {
    steps.value = await _healthService.getTodaySteps();
  }

  Future<void> syncNow({bool isRetry = false}) async {
    if (isSyncing.value) return;
    
    isSyncing.value = true;
    debugPrint("Sync process started...");

    try {
      final payload = await _healthService.fetchLatestSyncPayload();
      
      if (payload != null) {
        final userId = storage.getUserId();
        if (userId == null) {
          throw Exception("User ID not found. Please log in again.");
        }
        debugPrint("Sync payload: $payload");

        await _dio.dio.post('submissions/$userId', data: payload);

        final now = DateTime.parse(payload['payload']['timestamp']);
        await storage.saveLastSync(now);
        lastSync.value = now;
        
        await storage.addSyncLog(true, "Manual sync successful.");
        
        Get.snackbar("Success", "Health data synced successfully",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.accentColor,
          colorText: Colors.white);
      } else {
        await storage.addSyncLog(true, "Sync checked: No new data.");
        Get.snackbar("Info", "No new health data to sync",
          snackPosition: SnackPosition.BOTTOM);
      }
      
      await fetchLatestData();
      
    } catch (e) {
      debugPrint("Sync failed: $e");
      await storage.addSyncLog(false, "Sync failed: ${e.toString()}");
      
      if (!isRetry && e.toString().contains("Health permissions")) {
         // If it's a permission error, try to request again
         final granted = await _healthService.requestPermissions();
         if (granted) {
           return await syncNow(isRetry: true);
         }
      }

      Get.snackbar("Sync Error", e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white);
    } finally {
      isSyncing.value = false;
    }
  }
}