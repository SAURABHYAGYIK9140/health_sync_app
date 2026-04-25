import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../core/storage/storage_service.dart';
import '../core/network/dio_client.dart';

class SubmissionsService extends GetxService {
  final _storage = Get.find<StorageService>();
  final _dio = Get.find<DioClient>();

  Future<Map<String, dynamic>?> fetchUserSubmissions() async {
    try {
      final userId = _storage.getUserId();

      if (userId == null) {
        throw Exception("User ID not found. Please log in again.");
      }
      debugPrint("Fetching user submissions...");

      // GET /api/submissions/{user_id}
      final response = await _dio.dio.get('submissions/$userId');
      debugPrint("Submissions response: ${response.data}");

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSubmissionsList() async {
    try {
      final data = await fetchUserSubmissions();

      if (data != null && data.containsKey('submissions')) {
        final submissions = data['submissions'] as List;
        return submissions
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get total steps from all submissions
  Future<int> getTotalStepsFromSubmissions() async {
    try {
      final submissions = await getSubmissionsList();
      int totalSteps = 0;

      for (var submission in submissions) {
        if (submission.containsKey('payload')) {
          final payload = submission['payload'] as Map?;
          if (payload != null && payload.containsKey('steps')) {
            final stepsData = payload['steps'];
            if (stepsData is List) {
              for (var step in stepsData) {
                if (step is Map && step.containsKey('value')) {
                  final value = step['value'];
                  if (value is String) {
                    totalSteps += int.tryParse(value) ?? 0;
                  } else if (value is num) {
                    totalSteps += value.toInt();
                  }
                }
              }
            }
          }
        }
      }

      return totalSteps;
    } catch (e) {
      return 0;
    }
  }
}

