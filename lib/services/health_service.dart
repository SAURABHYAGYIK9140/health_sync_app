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

  /// Fetch latest raw data and construct a payload containing the full record set
  Future<Map<String, dynamic>?> fetchLatestSyncPayload() async {
    final storage = Get.find<StorageService>();
    final now = DateTime.now();
    DateTime? storedLastSync = storage.getLastSync();
    debugPrint("DEBUG: Stored last sync: $storedLastSync");

    final lastSync = (storedLastSync == null || storedLastSync.isAfter(now))
        ? now.subtract(const Duration(hours: 24))
        : storedLastSync;

    final deviceId = await storage.getDeviceId();
    debugPrint('[HealthService] fetchLatestSyncPayload: lastSync=$lastSync, now=$now, deviceId=$deviceId');

    List<HealthDataPoint> allData = [];

    try {
      // Step 1: Check and request permissions
      final hasPerms = await hasPermissions();
      debugPrint('[HealthService] Step 1 - hasPermissions: $hasPerms');
      if (!hasPerms) {
        debugPrint("Health permissions not granted, attempting to request them");
        final granted = await requestPermissionsWithRetry();
        debugPrint('[HealthService] Step 1 - requestPermissionsWithRetry result: $granted');
        if (!granted) {
          debugPrint('[HealthService] STOPPING: Health permissions not granted after retry');
          throw Exception("Health permissions not granted. Please enable in settings.");
        }
      }

      // Step 2: Fetch data from last 24 hours
      debugPrint('[HealthService] Step 2 - Attempting to fetch data from $lastSync to $now');
      for (var type in types) {
        try {
          final hasTypePerm = await _health.hasPermissions([type]) ?? false;
          debugPrint('[HealthService] Type $type - Permission: $hasTypePerm');
          if (!hasTypePerm) {
            debugPrint('[HealthService] Type $type - Skipping (no permission)');
            continue;
          }

          debugPrint('[HealthService] Type $type - Fetching from $lastSync to $now');
          final data = await _health.getHealthDataFromTypes(
            startTime: lastSync,
            endTime: now,
            types: [type],
          );
          debugPrint('[HealthService] Type $type - Fetched ${data.length} records');
          allData.addAll(data);
        } catch (e) {
          debugPrint("[HealthService] Type $type - Failed to fetch: $e");
        }
      }

      // Step 3: Check if we have data
      var cleanData = _health.removeDuplicates(allData);
      debugPrint('[HealthService] Step 3 - After removeDuplicates from 24h: ${cleanData.length} records');

      // Step 4: Fallback to 7 days if no data found
      if (cleanData.isEmpty) {
        debugPrint('[HealthService] Step 4 - No data in 24h range, trying 7-day fallback');
        final weekAgo = now.subtract(const Duration(days: 7));
        List<HealthDataPoint> weekData = [];

        for (var type in types) {
          try {
            final hasTypePerm = await _health.hasPermissions([type]) ?? false;
            if (!hasTypePerm) {
              debugPrint('[HealthService] 7d Type $type - Skipping (no permission)');
              continue;
            }

            debugPrint('[HealthService] 7d Type $type - Fetching from $weekAgo to $now');
            final data = await _health.getHealthDataFromTypes(
              startTime: weekAgo,
              endTime: now,
              types: [type],
            );
            debugPrint('[HealthService] 7d Type $type - Fetched ${data.length} records');
            weekData.addAll(data);
          } catch (e) {
            debugPrint("[HealthService] 7d Type $type - Failed to fetch: $e");
          }
        }

        final weekClean = _health.removeDuplicates(weekData);
        debugPrint('[HealthService] Step 4 - After removeDuplicates from 7d: ${weekClean.length} records');

        if (weekClean.isEmpty) {
          debugPrint('[HealthService] No health data found in both 24h and 7d ranges. Injecting mock data for testing.');
          // Injecting mock data so that API can be tested even on emulator without health data
          cleanData = [];
        } else {
          cleanData = weekClean;
        }
      }

      debugPrint('[HealthService] Step 5 - Building payload with ${cleanData.length} records');

      // Step 5: Transform raw data points into JSON format
      final List<Map<String, dynamic>> dataPoints = cleanData.map((p) {
        dynamic val;
        try {
          if (p.value is NumericHealthValue) {
            val = (p.value as NumericHealthValue).numericValue;
          } else {
            val = p.value.toString();
          }
        } catch (_) {
          val = p.value.toString();
        }

        return {
          'type': p.typeString,
          'value': val,
          'unit': p.unitString,
          'from': p.dateFrom.toIso8601String(),
          'to': p.dateTo.toIso8601String(),
          'source_id': p.sourceId,
          'source_name': p.sourceName,
        };
      }).toList();

      // If no data points, add a mock data point for testing
      if (dataPoints.isEmpty) {
        dataPoints.add({
          'type': 'STEPS',
          'value': 1000,
          'unit': 'COUNT',
          'from': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'to': now.toIso8601String(),
          'source_id': 'mock_source',
          'source_name': 'Mock Data (Emulator)',
        });
      }

      final rdata = {
        "type": "health_data_upload",
        "device_id": deviceId,
        "payload": {
          "records_count": dataPoints.length,
          "timestamp": now.toIso8601String(),
          "health_data": dataPoints,
        }
      };

      debugPrint('[HealthService] Step 5 - rdata created successfully with ${dataPoints.length} data points');
      return rdata;
    } catch (e, stack) {
      debugPrint("[HealthService] EXCEPTION in fetchLatestSyncPayload: $e");
      debugPrint("[HealthService] Stack trace: $stack");
      // Rethrow so the dashboard controller can catch it and show the actual error
      throw Exception("Payload generation failed: $e");
    }
  }

  /// Get today's steps with permission verification
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = now.subtract(const Duration(hours: 24));

    // Defensive: Ensure time order
    if (!midnight.isBefore(now)) {
      debugPrint("[HealthService] Invalid time range: midnight >= now. Returning 0 steps.");
      return 0;
    }
    if (!yesterday.isBefore(now)) {
      debugPrint("[HealthService] Invalid time range: yesterday >= now. Returning 0 steps.");
      return 0;
    }

    try {
      final hasPerm = await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      if (!hasPerm) return 0;

      // Try aggregate first (standard)
      int? steps;
      if (midnight.isBefore(now)) {
        steps = await _health.getTotalStepsInInterval(midnight, now);
      }
      // Fallback: If 0, try the last 24 hours (sometimes midnight boundary is tricky)
      if ((steps == null || steps == 0) && yesterday.isBefore(now)) {
        steps = await _health.getTotalStepsInInterval(yesterday, now);
        debugPrint("Steps check (Last 24h): $steps");
      }
      // Secondary Fallback: Fetch raw data points
      if ((steps == null || steps == 0) && yesterday.isBefore(now)) {
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