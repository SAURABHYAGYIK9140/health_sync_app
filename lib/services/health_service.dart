import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/storage/storage_service.dart';

class HealthService extends GetxService {
  final Health _health = Health();

  final List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Check Health Connect availability
  Future<bool> checkHealthConnect() async {
    if (!GetPlatform.isAndroid) return true;

    try {
      final isAvailable = await _health.getHealthConnectSdkStatus();
      debugPrint("Health Connect SDK Status: $isAvailable");
      return isAvailable == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint("Health Connect check failed: $e");
      return false;
    }
  }

  /// Open Play Store for Health Connect
  Future<void> openHealthConnectStore() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  /// Request required system permissions
  Future<bool> _requestSystemPermissions() async {
    try {
      debugPrint("Requesting system permissions: Activity & Sensors");
      Map<Permission, PermissionStatus> statuses = await [
        Permission.activityRecognition,
        Permission.sensors,
      ].request();
      
      final activityOk = statuses[Permission.activityRecognition]?.isGranted ?? false;
      final sensorsOk = statuses[Permission.sensors]?.isGranted ?? false;
      
      debugPrint("System permissions - Activity: $activityOk, Sensors: $sensorsOk");
      return activityOk; // Sensors is optional but recommended
    } catch (e) {
      debugPrint("System permission request failed: $e");
      return false;
    }
  }

  /// Request Health Connect permissions via Health package
  Future<bool> requestPermissions() async {
    try {
      debugPrint("Starting permission request process...");

      // Step 1: Request system Activity Recognition & Sensors
      if (GetPlatform.isAndroid) {
        await _requestSystemPermissions();
      }

      // Step 2: Check Health Connect status
      if (GetPlatform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint("Health Connect is not available: $status");
          if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
            await _health.installHealthConnect();
          }
          return false;
        }
      }

      // Step 3: Request Health Connect permissions
      final permissions = types.map((e) => HealthDataAccess.READ).toList();

      debugPrint("Requesting Health Data permissions for ${types.length} data types");
      
      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      debugPrint("Health permissions request result: $granted");

      // Verify at least STEPS are granted
      final verified = await hasPermissions();
      debugPrint("Verified Health permissions (Steps): $verified");

      return verified || granted;
    } catch (e) {
      debugPrint("Permission request exception: $e");
      return false;
    }
  }

  /// Check if essential Health Connect permissions are granted
  Future<bool> hasPermissions() async {
    try {
      // Return true if at least STEPS or any other data is accessible
      // This allows partial data fetching instead of failing everything
      final hasSteps = await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      final hasHeart = await _health.hasPermissions([HealthDataType.HEART_RATE]) ?? false;
      
      debugPrint("Permission status - Steps: $hasSteps, Heart Rate: $hasHeart");
      
      return hasSteps || hasHeart;
    } catch (e) {
      debugPrint("hasPermissions check failed: $e");
      return false;
    }
  }

  /// Request permissions with retry logic
  Future<bool> requestPermissionsWithRetry({int maxRetries = 1}) async {
    for (int i = 0; i <= maxRetries; i++) {
      final granted = await requestPermissions();
      if (granted) return true;
      
      if (i < maxRetries) {
        debugPrint("Permission request retry $i...");
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    return false;
  }

  /// Fetch latest data with permission verification
  Future<Map<String, dynamic>?> fetchLatestSyncPayload() async {
    final storage = Get.find<StorageService>();
    final lastSync = storage.getLastSync() ??
        DateTime.now().subtract(const Duration(hours: 24));

    final now = DateTime.now();
    final deviceId = await storage.getDeviceId();

    try {
      // Verify permissions before fetching
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        debugPrint("Health permissions not granted, attempting to request them");
        final granted = await requestPermissionsWithRetry();
        if (!granted) {
          throw Exception("Health permissions not granted. Please enable in settings.");
        }
      }

      debugPrint("Fetching health data from $lastSync to $now");
      
      // Fetch each type individually to prevent one failure from blocking all
      List<HealthDataPoint> allData = [];
      for (var type in types) {
        try {
          // Check permission for THIS specific type before fetching
          final hasTypePerm = await _health.hasPermissions([type]) ?? false;
          if (!hasTypePerm) {
            debugPrint("Skipping $type: Permission not granted");
            continue;
          }

          final data = await _health.getHealthDataFromTypes(
            startTime: lastSync,
            endTime: now,
            types: [type],
          );
          allData.addAll(data);
        } catch (e) {
          debugPrint("Failed to fetch $type: $e");
        }
      }

      final cleanData = _health.removeDuplicates(allData);
      debugPrint("Fetched ${cleanData.length} total health records");

      if (cleanData.isEmpty) return null;

      int steps = 0;
      double heartRate = 0;
      int hrCount = 0;
      double sleepHours = 0;
      double calories = 0;

      for (var p in cleanData) {
        if (p.type == HealthDataType.STEPS) {
          steps += (p.value as NumericHealthValue).numericValue.toInt();
        } else if (p.type == HealthDataType.HEART_RATE) {
          heartRate += (p.value as NumericHealthValue).numericValue.toDouble();
          hrCount++;
        } else if (p.type == HealthDataType.SLEEP_SESSION) {
          sleepHours += p.dateTo.difference(p.dateFrom).inMinutes / 60.0;
        } else if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          calories += (p.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      final payload = {
        "type": "health_sync",
        "device_id": deviceId,
        "payload": {
          "steps": steps,
          "heart_rate": hrCount > 0 ? (heartRate / hrCount).round() : 0,
          "sleep_hours": double.parse(sleepHours.toStringAsFixed(2)),
          "calories": calories.round(),
          "timestamp": now.toIso8601String(),
        }
      };
      debugPrint("Constructed sync payload: $payload");
      return payload;
    } catch (e) {
      debugPrint("Fetch health data failed: $e");
      return null;
    }
  }

  /// Get today's steps with permission verification
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = now.subtract(const Duration(hours: 24));

    try {
      final hasPerm = await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      if (!hasPerm) return 0;

      // Try aggregate first (standard)
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      
      // Fallback: If 0, try the last 24 hours (sometimes midnight boundary is tricky)
      if (steps == null || steps == 0) {
        steps = await _health.getTotalStepsInInterval(yesterday, now);
        debugPrint("Steps check (Last 24h): $steps");
      }
      
      // Secondary Fallback: Fetch raw data points
      if (steps == null || steps == 0) {
        final data = await _health.getHealthDataFromTypes(
          startTime: yesterday,
          endTime: now,
          types: [HealthDataType.STEPS],
        );
        for (var p in data) {
          steps = (steps ?? 0) + (p.value as NumericHealthValue).numericValue.toInt();
        }
      }
      
      return steps ?? 0;
    } catch (e) {
      debugPrint("getTodaySteps failed: $e");
      return 0;
    }
  }

  /// Get latest heart rate
  Future<int> getLatestHeartRate() async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 7)); // Look back 7 days for latest

    try {
      final hasPerm = await _health.hasPermissions([HealthDataType.HEART_RATE]) ?? false;
      if (!hasPerm) return 0;

      final data = await _health.getHealthDataFromTypes(
        startTime: past,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      
      debugPrint("DEBUG: Found ${data.length} heart rate points in last 7 days");
      
      if (data.isEmpty) return 0;
      
      // Get the most recent one
      data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      return (data.first.value as NumericHealthValue).numericValue.toInt();
    } catch (e) {
      debugPrint("getLatestHeartRate failed: $e");
      return 0;
    }
  }

  /// Get today's sleep duration in hours
  Future<double> getTodaySleep() async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 7)); // Look back 7 days

    try {
      final hasPerm = await _health.hasPermissions([HealthDataType.SLEEP_SESSION]) ?? false;
      if (!hasPerm) return 0.0;

      final data = await _health.getHealthDataFromTypes(
        startTime: past,
        endTime: now,
        types: [HealthDataType.SLEEP_SESSION],
      );
      
      debugPrint("DEBUG: Found ${data.length} sleep sessions in last 7 days");
      if (data.isEmpty) return 0.0;

      // Get sessions from today (last 24h)
      final todayLimit = DateTime.now().subtract(const Duration(hours: 24));
      double sleepHours = 0;
      for (var p in data) {
        if (p.dateFrom.isAfter(todayLimit)) {
          sleepHours += p.dateTo.difference(p.dateFrom).inMinutes / 60.0;
        }
      }
      
      // If no sleep today, show the last session duration
      if (sleepHours == 0 && data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        sleepHours = data.first.dateTo.difference(data.first.dateFrom).inMinutes / 60.0;
      }

      return double.parse(sleepHours.toStringAsFixed(1));
    } catch (e) {
      debugPrint("getTodaySleep failed: $e");
      return 0.0;
    }
  }

  /// Get today's calories burned
  Future<int> getTodayCalories() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      final hasPerm = await _health.hasPermissions([HealthDataType.ACTIVE_ENERGY_BURNED]) ?? false;
      if (!hasPerm) return 0;

      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      
      double calories = 0;
      for (var p in data) {
        calories += (p.value as NumericHealthValue).numericValue.toDouble();
      }
      debugPrint("DEBUG: Found ${data.length} calorie records today");
      return calories.round();
    } catch (e) {
      debugPrint("getTodayCalories failed: $e");
      return 0;
    }
  }

  /// Open Health Connect app or store
  Future<void> openHealthConnectApp() async {
    final uri = Uri.parse('healthconnect://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await openHealthConnectStore();
    }
  }
}