import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../services/health_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class DashboardController extends GetxController with WidgetsBindingObserver {
  final _healthService = Get.find<HealthService>();
  final storage = Get.find<StorageService>();
  final _dio = Get.find<DioClient>();

  final steps = 0.obs;
  final heartRate = 0.obs;
  final sleepHours = 0.0.obs;
  final calories = 0.obs;
  final isSyncing = false.obs;
  final hasHealthAccess = true.obs;
  final isHealthConnectInstalled = true.obs; // false only on Android when HC is missing
  final lastSync = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    lastSync.value = storage.getLastSync();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Auto-recheck Health Connect when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have just installed Health Connect from Play Store
      if (!isHealthConnectInstalled.value) {
        recheckHealthConnect();
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    // Delay slightly to ensure Activity is attached
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 1: Check if Health Connect is installed (Android only)
    final hcInstalled = await _healthService.checkHealthConnect();
    isHealthConnectInstalled.value = hcInstalled;
    debugPrint("[DashboardController] Health Connect installed: $hcInstalled");

    if (!hcInstalled) {
      // Don't proceed further — show install prompt
      debugPrint("[DashboardController] Health Connect not installed. Showing install prompt.");
      return;
    }

    // Step 2: Check permissions
    await _handleHealthPermissions();

    // Step 3: Only proceed if permissions are granted
    if (!hasHealthAccess.value) {
      debugPrint("[DashboardController] Permissions not granted. Stopping init — waiting for user.");
      return; // Background service will NOT start until user grants access
    }

    // Step 4: Load data, auto-sync & start background service
    await fetchLatestData();
    // Auto-sync on app open — no manual button needed
    syncNow();

    final token = await storage.getToken();
    debugPrint("Payload: $token");
    _startBackgroundServiceSafe();
  }

  Future<void> _handleHealthPermissions() async {
    final hasPermission = await _healthService.hasPermissions();
    hasHealthAccess.value = hasPermission;

    if (!hasPermission) {
      debugPrint("Health permission missing, waiting for user action...");
    } else {
      debugPrint("Health permissions confirmed");
    }
  }

  /// Called when user taps "Install Health Connect" button
  Future<void> promptInstallHealthConnect() async {
    await _healthService.openHealthConnectStore();
  }

  /// Re-check Health Connect after user returns from Play Store
  Future<void> recheckHealthConnect() async {
    final hcInstalled = await _healthService.checkHealthConnect();
    isHealthConnectInstalled.value = hcInstalled;
    debugPrint("[DashboardController] Re-check Health Connect installed: $hcInstalled");

    if (hcInstalled) {
      await _handleHealthPermissions();
      await fetchLatestData();
      _startBackgroundServiceSafe();
    }
  }

  Future<void> requestHealthAccess() async {
    // Step 1: Check if Health Connect is installed (same as PermissionsController)
    final isInstalled = await _healthService.checkHealthConnect();
    isHealthConnectInstalled.value = isInstalled;

    if (!isInstalled) {
      Get.defaultDialog(
        title: "Health Connect Required",
        middleText: "Install Health Connect to sync your health data.",
        textConfirm: "Install",
        textCancel: "Cancel",
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          _healthService.openHealthConnectStore();
        },
      );
      return;
    }

    // Step 2: Request permissions (same as PermissionsController)
    final granted = await _healthService.requestPermissions();
    debugPrint("[Dashboard] Health Permission Granted: $granted");
    hasHealthAccess.value = granted;

    if (granted) {
      await fetchLatestData();
      _startBackgroundServiceSafe();
    } else {
      // Show retry dialog if permissions not granted
      Get.defaultDialog(
        title: "Permission Required",
        middleText: "Health data access is needed to show your activity. Please allow access.",
        textConfirm: "Retry",
        textCancel: "Cancel",
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          requestHealthAccess(); // Retry the full flow
        },
      );
    }
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
    try {
      steps.value = await _healthService.getTodaySteps();
      debugPrint("[Dashboard] Steps fetched: ${steps.value}");
    } catch (e) {
      debugPrint("[Dashboard] Steps fetch failed: $e");
    }

    try {
      heartRate.value = await _healthService.getLatestHeartRate();
      debugPrint("[Dashboard] Heart rate fetched: ${heartRate.value}");
    } catch (e) {
      debugPrint("[Dashboard] Heart rate fetch failed: $e");
    }

    try {
      sleepHours.value = await _healthService.getTodaySleep();
      debugPrint("[Dashboard] Sleep fetched: ${sleepHours.value}");
    } catch (e) {
      debugPrint("[Dashboard] Sleep fetch failed: $e");
    }

    try {
      calories.value = await _healthService.getTodayCalories();
      debugPrint("[Dashboard] Calories fetched: ${calories.value}");
    } catch (e) {
      debugPrint("[Dashboard] Calories fetch failed: $e");
    }

    // Show only real data - no mock fallback values
  }

  Future<void> syncNow({bool isRetry = false}) async {
    if (isSyncing.value) {
      debugPrint("Sync already in progress, skipping.");
      return;
    }
    isSyncing.value = true;
    debugPrint("Sync process started...");

    try {

      // Step 1: Force a permission check before syncing
      final hasPerm = await _healthService.hasPermissions();
      debugPrint("[syncNow] hasPermissions: $hasPerm");
      if (!hasPerm) {
        debugPrint("Health permissions not granted, attempting to request them");
        final granted = await _healthService.requestPermissions();
        debugPrint("[syncNow] requestPermissions result: $granted");
        if (!granted) {
          final msg = "Sync failed: Health permissions are required.";
          debugPrint(msg);
          await storage.addSyncLog(false, msg);
          Get.snackbar("Sync Error", "Health permissions are required.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
            duration: const Duration(seconds: 5));
          return;
        }
      }

      final payload = await _healthService.fetchLatestSyncPayload();
      debugPrint("[syncNow] Payload: $payload");

      if (payload != null) {
        final userId = storage.getUserId();
        final deviceId = await storage.getDeviceId();
        if (userId == null) {
          final msg = "User ID not found. Please log in again.";
          debugPrint(msg);
          await storage.addSyncLog(false, msg);
          Get.snackbar("Sync Error", msg,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
            duration: const Duration(seconds: 5));
          return;
        }
        final url = '${_dio.dio.options.baseUrl}submissions';
        debugPrint("DEBUG MODE - MULTIPART SYNC START");
        debugPrint("URL: $url");

        // Create FormData for multipart file upload
        final formData = dio_pkg.FormData.fromMap({
          'type': payload['type'] ?? 'health_data_upload',
          'device_id': deviceId ?? '',
          'payload': jsonEncode(payload['payload'] ?? {}),
          'file': dio_pkg.MultipartFile.fromString(
            jsonEncode(payload),
            filename: 'health_data_${DateTime.now().millisecondsSinceEpoch}.json',
          ),
        });

        // Use a timeout to prevent the infinite loading spinner
        final response = await _dio.dio.post(
          'submissions', 
          data: formData,
          options: dio_pkg.Options(
            contentType: 'multipart/form-data',
          ),
        ).timeout(const Duration(seconds: 30));

        debugPrint("DEBUG MODE - SYNC SUCCESS");
        debugPrint("RESPONSE STATUS: ${response.statusCode}");
        debugPrint("RESPONSE DATA: ${jsonEncode(response.data)}");

        final now = DateTime.parse(payload['payload']['timestamp']);
        await storage.saveLastSync(now);
        lastSync.value = now;
        await storage.addSyncLog(true, "Manual sync successful.");
        Get.snackbar("Success", "Health data synced successfully",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.accentColor,
          colorText: Colors.white);
      } else {
        final msg = "Sync checked: No data found to upload.";
        debugPrint("[syncNow] $msg");
        await storage.addSyncLog(true, msg);
        Get.snackbar("Info", "No data found to sync. Try recording some activity!",
          snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
      String errorMsg = e.toString();
      if (e is Exception && e.toString().contains("timeout")) {
        errorMsg = "Server connection timed out. Please try again later.";
      }
      await storage.addSyncLog(false, "Sync failed: $errorMsg");
      Get.snackbar("Sync Error", errorMsg.replaceAll("Exception:", ""),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 5));
    } finally {
      isSyncing.value = false;
      await fetchLatestData();
    }
  }
}