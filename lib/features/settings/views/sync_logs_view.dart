import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class SyncLogsView extends StatelessWidget {
  const SyncLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    final logs = storage.getSyncLogs();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Sync History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: logs.isEmpty
          ? const Center(child: Text("No logs available yet."))
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = logs[index];
                final timestamp = DateTime.parse(log['timestamp']);
                final success = log['success'] as bool;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        success ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: success ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['message'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, hh:mm:ss a').format(timestamp),
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
