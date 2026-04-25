import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_sync_app/core/storage/storage_service.dart';
import 'package:intl/intl.dart';
import '../../../services/submissions_service.dart';
import '../../../core/theme/app_theme.dart';

class SubmissionsView extends StatelessWidget {
  const SubmissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final submissionsService = Get.find<SubmissionsService>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Submissions History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: submissionsService.getSubmissionsList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No submissions yet"),
            );
          }

          final submissions = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: submissions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final submission = submissions[index];
              final type = submission['type'] as String? ?? 'Unknown';
              final createdAt = submission['created_at'] as String?;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${submission['id']}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (createdAt != null) ...[
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(
                          DateTime.parse(createdAt),
                        ),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPayloadWidget(submission['payload']),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPayloadWidget(dynamic payload) {
    if (payload == null || payload is! Map) {
      return const SizedBox.shrink();
    }

    final payloadMap = Map<String, dynamic>.from(payload);
    final widgets = <Widget>[];

    double _sumList(List list) {
      double total = 0;
      for (var item in list) {
        if (item is Map && item.containsKey('value')) {
          final v = item['value'];

          if (v is String) {
            total += double.tryParse(v.split(':').first) ?? 0; // handles time also
          } else if (v is num) {
            total += v.toDouble();
          }
        }
      }
      return total;
    }

    //  Steps
    if (payloadMap['steps'] is List) {
      final totalSteps = _sumList(payloadMap['steps']).toInt();
      if (totalSteps > 0) {
        widgets.add(
          _buildDataRow(Icons.directions_walk_rounded, 'Steps', '$totalSteps'),
        );
      }
    }

    //  Calories
    if (payloadMap['caloriesBurned'] is List) {
      final calories = _sumList(payloadMap['caloriesBurned']).toInt();
      if (calories > 0) {
        widgets.add(
          _buildDataRow(Icons.local_fire_department_rounded, 'Calories', '$calories kcal'),
        );
      }
    }

    //  Distance
    if (payloadMap['distance'] is List) {
      final distance = _sumList(payloadMap['distance']);
      if (distance > 0) {
        widgets.add(
          _buildDataRow(Icons.route_rounded, 'Distance', '${distance.toStringAsFixed(1)} m'),
        );
      }
    }

    //  Sleep Duration
    if (payloadMap['sleepDuration'] is List) {
      final sleepMinutes = _sumList(payloadMap['sleepDuration']);
      if (sleepMinutes > 0) {
        final hours = (sleepMinutes / 60).toStringAsFixed(1);
        widgets.add(
          _buildDataRow(Icons.nightlight_rounded, 'Sleep', '$hours h'),
        );
      }
    }

    //  Heart Rate (average)
    if (payloadMap['heartRate'] is List) {
      final list = payloadMap['heartRate'] as List;
      if (list.isNotEmpty) {
        double total = 0;
        int count = 0;

        for (var item in list) {
          if (item is Map && item['value'] != null) {
            final v = item['value'];
            if (v is String) {
              total += double.tryParse(v.split(':').first) ?? 0;
            } else if (v is num) {
              total += v.toDouble();
            }
            count++;
          }
        }

        if (count > 0) {
          final avg = (total / count).toInt();
          widgets.add(
            _buildDataRow(Icons.favorite_rounded, 'Heart Rate', '$avg BPM'),
          );
        }
      }
    }

    //  Exercise Duration
    if (payloadMap['exercise'] is List) {
      final totalHours = _sumList(payloadMap['exercise']);
      if (totalHours > 0) {
        widgets.add(
          _buildDataRow(Icons.fitness_center_rounded, 'Exercise', '${totalHours.toStringAsFixed(1)} h'),
        );
      }
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: List.generate(
        widgets.length,
            (index) => Column(
          children: [
            widgets[index],
            if (index < widgets.length - 1) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Widget _buildDataRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

