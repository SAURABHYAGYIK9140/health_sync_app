import 'dart:ui';

import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/health_service.dart';

class PermissionsController extends GetxController {
  final _healthService = Get.find<HealthService>();

  final currentStep = 0.obs;
  final totalSteps = 4;

  final isHealthAuthorized = false.obs;
  final isLocationAuthorized = false.obs;
  final isCameraAuthorized = false.obs;
  final isMicrophoneAuthorized = false.obs;

  // ---------------- HEALTH ----------------
  Future<void> requestHealthPermission() async {
    final isInstalled = await _healthService.checkHealthConnect();

    if (!isInstalled) {
      Get.defaultDialog(
        title: "Health Connect Required",
        middleText: "Install Health Connect to continue.",
        textConfirm: "Install",
        textCancel: "Cancel",
        onConfirm: () => _healthService.openHealthConnectStore(),
      );
      return;
    }

    // 👉 ONLY trigger permission
    final granted = await _healthService.requestPermissions();
    print("Health Permission Granted: $granted");
    isHealthAuthorized.value = true;
    nextStep();
    if (granted) {

    } else {
      // isHealthAuthorized.value = false;
      //
      // // keep your dialog but simplified
      // Get.defaultDialog(
      //   title: "Permission Required",
      //   middleText:
      //   "Please allow Health access from the permission screen.",
      //   textConfirm: "Retry",
      //   textCancel: "Cancel",
      //   onConfirm: () {
      //     Get.back();
      //     requestHealthPermission();
      //   },
      // );
    }
  }

  // ---------------- LOCATION ----------------
  Future<void> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    _handlePermission(
      status,
      onGranted: () {
        isLocationAuthorized.value = true;
        nextStep();
      },
      message: "Location permission required",
    );
  }

  // ---------------- CAMERA ----------------
  Future<void> requestCameraPermission() async {
    final status = await Permission.camera.request();
    _handlePermission(
      status,
      onGranted: () {
        isCameraAuthorized.value = true;
        nextStep();
      },
      message: "Camera permission required",
    );
  }

  // ---------------- MICROPHONE ----------------
  Future<void> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    _handlePermission(
      status,
      onGranted: () {
        isMicrophoneAuthorized.value = true;
        nextStep();
      },
      message: "Microphone permission required",
    );
  }

  // ---------------- COMMON HANDLER ----------------
  void _handlePermission(
      PermissionStatus status, {
        required VoidCallback onGranted,
        required String message,
      }) {
    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied) {
      Get.defaultDialog(
        title: "Permission Required",
        middleText: "$message. Enable it from settings.",
        textConfirm: "Open Settings",
        onConfirm: openAppSettings,
      );
    } else {
      Get.snackbar("Permission Denied", message);
    }
  }

  // ---------------- FLOW ----------------
  void nextStep() {
    if (currentStep.value < totalSteps - 1) {
      currentStep.value++;
    } else {
      Get.offNamed('/dashboard');
    }
  }

  void skip() {
    Get.offNamed('/dashboard');
  }
}