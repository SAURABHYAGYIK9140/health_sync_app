import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/dashboard/controllers/dashboard_controller.dart';

class LifecycleController extends GetxController with WidgetsBindingObserver {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if sync is needed or was interrupted
      if (Get.isRegistered<DashboardController>()) {
        final dashboard = Get.find<DashboardController>();
        dashboard.fetchLatestData();
        
        // If it's been along time since last sync, trigger auto sync
        final lastSync = dashboard.lastSync.value;
        if (lastSync == null || DateTime.now().difference(lastSync).inHours >= 24) {
          dashboard.syncNow();
        }
      }
    }
  }
}
