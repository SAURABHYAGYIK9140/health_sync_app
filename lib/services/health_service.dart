import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/storage/storage_service.dart';
import 'location_service.dart';

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

      final activityOk =
          statuses[Permission.activityRecognition]?.isGranted ?? false;
      final sensorsOk = statuses[Permission.sensors]?.isGranted ?? false;

      debugPrint(
        "System permissions - Activity: $activityOk, Sensors: $sensorsOk",
      );
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
          if (status ==
              HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
            await _health.installHealthConnect();
          }
          return false;
        }
      }

      // Step 3: Request Health Connect permissions
      final permissions = types.map((e) => HealthDataAccess.READ).toList();

      debugPrint(
        "Requesting Health Data permissions for ${types.length} data types",
      );

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      debugPrint("Health permissions request result: $granted");

      // If requestAuthorization says granted, trust it (don't re-verify —
      // hasPermissions() is unreliable on Android 10)
      if (granted) return true;

      // Fallback: requestAuthorization returned false, but double-check
      // with our practical data-read test
      final verified = await hasPermissions();
      debugPrint("Fallback hasPermissions check: $verified");
      return verified;
    } catch (e) {
      debugPrint("Permission request exception: $e");
      return false;
    }
  }

  /// Check if essential Health Connect permissions are granted.
  ///
  /// On Android 10 (API 29), the `hasPermissions()` API from the health package
  /// is unreliable and may return false even when permissions ARE granted.
  /// We use a practical fallback: try to actually read data. If it succeeds
  /// (even 0 results), we have real access. Only a SecurityException means
  /// we truly lack permissions.
  Future<bool> hasPermissions() async {
    try {
      // Step 1: Try the standard API first
      final hasSteps =
          await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      final hasHeart =
          await _health.hasPermissions([HealthDataType.HEART_RATE]) ?? false;

      debugPrint(
        "Permission status (API) - Steps: $hasSteps, Heart Rate: $hasHeart",
      );

      if (hasSteps || hasHeart) return true;

      // Step 2: API says false — but on Android 10 this can be wrong.
      // Try a real data fetch as the ground-truth check.
      debugPrint(
        "hasPermissions API returned false — trying practical data-read check...",
      );
      return await _canActuallyReadData();
    } catch (e) {
      debugPrint("hasPermissions check failed: $e");
      return false;
    }
  }

  /// Attempt a real data read to verify we have actual access.
  /// Returns true if the read completes without a SecurityException.
  Future<bool> _canActuallyReadData() async {
    try {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));

      // A successful call (even with 0 results) means we have permission.
      // A SecurityException means we don't.
      await _health.getHealthDataFromTypes(
        startTime: past,
        endTime: now,
        types: [HealthDataType.STEPS],
      );

      debugPrint("Practical permission check: SUCCESS (data read succeeded)");
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('security') ||
          errorStr.contains('permission') ||
          errorStr.contains('unauthorized')) {
        debugPrint(
          "Practical permission check: FAILED (SecurityException) — $e",
        );
        return false;
      }
      // Other errors (network, timeout, etc.) — assume we have permission
      // but something else went wrong
      debugPrint(
        "Practical permission check: AMBIGUOUS error (assuming granted) — $e",
      );
      return true;
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
    debugPrint(
      '[HealthService] fetchLatestSyncPayload: lastSync=$lastSync, now=$now, deviceId=$deviceId',
    );

    List<HealthDataPoint> allData = [];

    try {
      // Step 1: Check and request permissions
      final hasPerms = await hasPermissions();
      debugPrint('[HealthService] Step 1 - hasPermissions: $hasPerms');
      if (!hasPerms) {
        debugPrint(
          "Health permissions not granted, attempting to request them",
        );
        final granted = await requestPermissionsWithRetry();
        debugPrint(
          '[HealthService] Step 1 - requestPermissionsWithRetry result: $granted',
        );
        if (!granted) {
          debugPrint(
            '[HealthService] STOPPING: Health permissions not granted after retry',
          );
          throw Exception(
            "Health permissions not granted. Please enable in settings.",
          );
        }
      }

      // Step 2: Fetch data from last 24 hours
      debugPrint(
        '[HealthService] Step 2 - Attempting to fetch data from $lastSync to $now',
      );
      for (var type in types) {
        try {
          // Skip unreliable hasPermissions() check — just try to read.
          // A SecurityException means no permission; empty results are fine.
          debugPrint(
            '[HealthService] Type $type - Fetching from $lastSync to $now',
          );
          final data = await _health.getHealthDataFromTypes(
            startTime: lastSync,
            endTime: now,
            types: [type],
          );
          debugPrint(
            '[HealthService] Type $type - Fetched ${data.length} records',
          );
          allData.addAll(data);
        } catch (e) {
          debugPrint("[HealthService] Type $type - Failed to fetch: $e");
        }
      }

      // Step 3: Check if we have data
      var cleanData = _health.removeDuplicates(allData);
      debugPrint(
        '[HealthService] Step 3 - After removeDuplicates from 24h: ${cleanData.length} records',
      );

      // Step 4: Fallback to 7 days if no data found
      if (cleanData.isEmpty) {
        debugPrint(
          '[HealthService] Step 4 - No data in 24h range, trying 7-day fallback',
        );
        final weekAgo = now.subtract(const Duration(days: 7));
        List<HealthDataPoint> weekData = [];

        for (var type in types) {
          try {
            debugPrint(
              '[HealthService] 7d Type $type - Fetching from $weekAgo to $now',
            );
            final data = await _health.getHealthDataFromTypes(
              startTime: weekAgo,
              endTime: now,
              types: [type],
            );
            debugPrint(
              '[HealthService] 7d Type $type - Fetched ${data.length} records',
            );
            weekData.addAll(data);
          } catch (e) {
            debugPrint("[HealthService] 7d Type $type - Failed to fetch: $e");
          }
        }

        final weekClean = _health.removeDuplicates(weekData);
        debugPrint(
          '[HealthService] Step 4 - After removeDuplicates from 7d: ${weekClean.length} records',
        );

        if (weekClean.isEmpty) {
          debugPrint(
            '[HealthService] No health data found in both 24h and 7d ranges.',
          );
          cleanData = [];
        } else {
          cleanData = weekClean;
        }
      }

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

       debugPrint(
         '[HealthService] Step 5 - Building payload with ${dataPoints.length} data points',
       );

       // Step 6: Fetch current metrics (BPM, Calories, Location)
       final latestBpm = await getLatestHeartRate();
       final todayCalories = await getTodayCalories();
       final locationService = Get.find<LocationService>();
       final location = await locationService.getCurrentLocation();

       debugPrint(
         '❤️ [SyncPayload] BPM: $latestBpm, 🔥 Calories: $todayCalories, 📍 Location: ${location ?? "unavailable"}',
       );

       final rdata = {
         "type": "health_data_upload",
         "device_id": deviceId,
         "payload": {
           "records_count": dataPoints.length,
           "timestamp": now.toIso8601String(),
           "health_data": dataPoints,
           "summary": {
             "heart_rate_bpm": latestBpm,
             "calories_burned": todayCalories,
             "latitude": location?['latitude'],
             "longitude": location?['longitude'],
           },
         },
       };

      debugPrint(
        '[HealthService] Step 5 - rdata created successfully with ${dataPoints.length} data points',
      );
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
       debugPrint(
         "🚶 [Steps] Invalid time range: midnight >= now. Returning 0 steps.",
       );
       return 0;
     }
     if (!yesterday.isBefore(now)) {
       debugPrint(
         "🚶 [Steps] Invalid time range: yesterday >= now. Returning 0 steps.",
       );
       return 0;
     }

     try {
       // Skip unreliable hasPermissions() — just try to read data directly.
       // Try aggregate first (standard)
       int? steps;
       if (midnight.isBefore(now)) {
         steps = await _health.getTotalStepsInInterval(midnight, now);
       }
       // Fallback: If 0, try the last 24 hours (sometimes midnight boundary is tricky)
       if ((steps == null || steps == 0) && yesterday.isBefore(now)) {
         steps = await _health.getTotalStepsInInterval(yesterday, now);
         debugPrint("🚶 [Steps] Fallback check (Last 24h): $steps");
       }
       // Secondary Fallback: Fetch raw data points
       if ((steps == null || steps == 0) && yesterday.isBefore(now)) {
         final data = await _health.getHealthDataFromTypes(
           startTime: yesterday,
           endTime: now,
           types: [HealthDataType.STEPS],
         );
         debugPrint("🚶 [Steps] Found ${data.length} step records in last 24h");
         for (var p in data) {
           steps =
               (steps ?? 0) +
               (p.value as NumericHealthValue).numericValue.toInt();
         }
       }
       final finalSteps = steps ?? 0;
       debugPrint("🚶 [Steps] Today's total: $finalSteps");
       return finalSteps;
     } catch (e) {
       debugPrint("❌ [Steps] Error: $e");
       return 0;
     }
   }

   /// Get latest heart rate
   Future<int> getLatestHeartRate() async {
     final now = DateTime.now();
     final past = now.subtract(
       const Duration(days: 7),
     ); // Look back 7 days for latest

     try {
       // Skip unreliable hasPermissions() — just try to read data directly.
       final data = await _health.getHealthDataFromTypes(
         startTime: past,
         endTime: now,
         types: [HealthDataType.HEART_RATE],
       );

       debugPrint(
         "❤️ [HeartRate] Found ${data.length} BPM readings in last 7 days",
       );

       if (data.isEmpty) {
         debugPrint("❤️ [HeartRate] No BPM data found. Recording device not detected or no permission to read.");
         return 0;
       }

       // Get the most recent one
       data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
       final latestBpm = (data.first.value as NumericHealthValue).numericValue.toInt();
       final timestamp = data.first.dateFrom;
       debugPrint("❤️ [HeartRate] Latest BPM: $latestBpm (recorded: $timestamp)");
       return latestBpm;
     } catch (e) {
       debugPrint("❌ [HeartRate] Error fetching BPM: $e");
       return 0;
     }
   }

   /// Get today's sleep duration in hours
   Future<double> getTodaySleep() async {
     final now = DateTime.now();
     final past = now.subtract(const Duration(days: 7)); // Look back 7 days

     try {
       // Skip unreliable hasPermissions() — just try to read data directly.
       final data = await _health.getHealthDataFromTypes(
         startTime: past,
         endTime: now,
         types: [HealthDataType.SLEEP_SESSION],
       );

       debugPrint("🛏️ [Sleep] Found ${data.length} sleep sessions in last 7 days");
       if (data.isEmpty) {
         debugPrint("🛏️ [Sleep] No sleep data. Ensure you have recorded sleep sessions.");
         return 0.0;
       }

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
         sleepHours =
             data.first.dateTo.difference(data.first.dateFrom).inMinutes / 60.0;
         debugPrint("🛏️ [Sleep] No sleep today, showing latest session: ${sleepHours.toStringAsFixed(1)}h");
       } else {
         debugPrint("🛏️ [Sleep] Today's sleep: ${sleepHours.toStringAsFixed(1)}h");
       }

       return double.parse(sleepHours.toStringAsFixed(1));
     } catch (e) {
       debugPrint("❌ [Sleep] Error: $e");
       return 0.0;
     }
   }

   /// Get today's calories burned
   Future<int> getTodayCalories() async {
     final now = DateTime.now();
     final midnight = DateTime(now.year, now.month, now.day);
     final yesterday = now.subtract(const Duration(hours: 24));

     try {
       // Skip unreliable hasPermissions() — just try to read data directly.
       double calories = 0;

       // Try ACTIVE_ENERGY_BURNED from midnight first
       final data = await _health.getHealthDataFromTypes(
         startTime: midnight,
         endTime: now,
         types: [HealthDataType.ACTIVE_ENERGY_BURNED],
       );
       for (var p in data) {
         calories += (p.value as NumericHealthValue).numericValue.toDouble();
       }
       debugPrint(
         "🔥 [Calories] Found ${data.length} ACTIVE_ENERGY records today, total=${calories.round()}",
       );

       // Fallback: try last 24h if midnight range returned nothing
       if (calories == 0) {
         final data24h = await _health.getHealthDataFromTypes(
           startTime: yesterday,
           endTime: now,
           types: [HealthDataType.ACTIVE_ENERGY_BURNED],
         );
         for (var p in data24h) {
           calories += (p.value as NumericHealthValue).numericValue.toDouble();
         }
         debugPrint(
           "🔥 [Calories] 24h fallback: Found ${data24h.length} records, total=${calories.round()}",
         );
       }

       // Secondary fallback: try BASAL_ENERGY_BURNED (some devices use this)
       if (calories == 0) {
         try {
           final basalData = await _health.getHealthDataFromTypes(
             startTime: yesterday,
             endTime: now,
             types: [HealthDataType.BASAL_ENERGY_BURNED],
           );
           for (var p in basalData) {
             calories += (p.value as NumericHealthValue).numericValue.toDouble();
           }
           debugPrint(
             "🔥 [Calories] Found ${basalData.length} BASAL_ENERGY records, total=${calories.round()}",
           );
         } catch (e) {
           debugPrint("⚠️ [Calories] BASAL_ENERGY fetch failed (optional): $e");
         }
       }

       if (calories == 0) {
         debugPrint("🔥 [Calories] No calorie data found. Ensure your device records activity.");
       }

       return calories.round();
     } catch (e) {
       debugPrint("❌ [Calories] Error: $e");
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
