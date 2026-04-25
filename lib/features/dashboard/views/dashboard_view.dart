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
              const SizedBox(height: 32),
              _buildSyncStatusCard(),
              const SizedBox(height: 32),
              Text("Today's Activity", 
                style: Get.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMainStats(),
              const SizedBox(height: 24),
              _buildOtherStats(),
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
                          : (controller.lastSync.value != null ? "Sync Success" : "Sync Required"),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    )),
                    Obx(() => Text(
                      controller.lastSync.value != null
                          ? "Last sync: ${DateFormat('hh:mm a').format(controller.lastSync.value!)}"
                          : "Tap to synchronize data",
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() => ElevatedButton(
            onPressed: controller.isSyncing.value ? null : controller.syncNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: controller.isSyncing.value
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Sync Now", style: TextStyle(fontWeight: FontWeight.bold)),
          )),
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
        _buildSmallStatCard("Heart Rate", "72 bpm", Icons.favorite_rounded, Colors.redAccent),
        const SizedBox(width: 16),
        _buildSmallStatCard("Sleep", "7h 20m", Icons.nightlight_rounded, Colors.indigoAccent),
      ],
    );
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
