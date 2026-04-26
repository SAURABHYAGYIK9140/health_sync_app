import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/theme/app_theme.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: ElevatedButton.icon(
          onPressed: () => Get.toNamed('/submissions'),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text("History"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            foregroundColor: AppTheme.primaryColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: controller.fetchLatestData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              // Health Connect not installed banner (Android only)
              Obx(() => !controller.isHealthConnectInstalled.value
                  ? _buildHealthConnectInstallCard()
                  : const SizedBox.shrink()),
              // Permissions warning (shown only when HC is installed but perms missing)
              Obx(() => controller.isHealthConnectInstalled.value &&
                      !controller.hasHealthAccess.value
                  ? _buildPermissionWarning()
                  : const SizedBox.shrink()),
              const SizedBox(height: 32),
              _buildSyncStatusCard(),
              const SizedBox(height: 32),
              Text("Today's Activity", 
                style: Get.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMainStats(),
              const SizedBox(height: 24),
              _buildOtherStats(),
              const SizedBox(height: 24),
              _buildCaloriesStat(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello,", style: Get.textTheme.titleMedium?.copyWith(color: Colors.black54)),
        Text(controller.storage.getUserEmail().toString().replaceAll
          ('@gmail.com', ''), style: Get.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHealthConnectInstallCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A73E8).withOpacity(0.08),
            const Color(0xFF4285F4).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF1A73E8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Health Connect Required",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Install Google's Health Connect to sync your health data.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.promptInstallHealthConnect,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text("Install Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: controller.recheckHealthConnect,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Re-check"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                  side: const BorderSide(color: Color(0xFF1A73E8)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Health data access is required to show your activity.",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: controller.requestHealthAccess,
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Grant Access"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Obx(() => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: controller.isSyncing.value 
                      ? Colors.orange.withOpacity(0.1) 
                      : (controller.lastSync.value != null ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  controller.isSyncing.value 
                      ? Icons.sync_rounded 
                      : (controller.lastSync.value != null ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded),
                  color: controller.isSyncing.value 
                      ? Colors.orange 
                      : (controller.lastSync.value != null ? Colors.green : Colors.red),
                ),
              )),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => Text(
                      controller.isSyncing.value 
                          ? "Syncing in progress..." 
                          : (controller.lastSync.value != null ? "Sync Success" : "Waiting to sync"),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    )),
                    Obx(() => Text(
                      controller.isSyncing.value
                          ? "Auto-syncing your health data..."
                          : (controller.lastSync.value != null
                              ? "Last sync: ${DateFormat('hh:mm a').format(controller.lastSync.value!)}"
                              : "Data syncs automatically on open"),
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    )),
                  ],
                ),
              ),
            ],
          ),
          // Show a progress bar while syncing
          Obx(() => controller.isSyncing.value
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0xFFE0E0E0),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildMainStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_walk_rounded, color: AppTheme.accentColor, size: 48),
          const SizedBox(height: 16),
          Obx(() => Text(
            "${controller.steps.value}",
            style: Get.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
          )),
          Text("Steps walked today", style: Get.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildOtherStats() {
    return Row(
      children: [
        Obx(() => _buildSmallStatCard(
          "Heart Rate", 
          "${controller.heartRate.value} bpm", 
          Icons.favorite_rounded, 
          Colors.redAccent
        )),
        const SizedBox(width: 16),
        Obx(() => _buildSmallStatCard(
          "Sleep", 
          "${controller.sleepHours.value}h", 
          Icons.nightlight_rounded, 
          Colors.indigoAccent
        )),
      ],
    );
  }

  Widget _buildCaloriesStat() {
    return Obx(() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Calories Burned", style: TextStyle(color: Colors.black54, fontSize: 13)),
                Text("${controller.calories.value} kcal", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
