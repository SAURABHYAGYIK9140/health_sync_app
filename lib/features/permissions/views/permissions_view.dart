import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/permissions_controller.dart';
import '../../../core/theme/app_theme.dart';

class PermissionsView extends GetView<PermissionsController> {
  const PermissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Obx(() => Column(
            children: [
              // Progress Bar
              Row(
                children: List.generate(controller.totalSteps, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= controller.currentStep.value 
                            ? AppTheme.primaryColor 
                            : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              
              // Content based on step
              if (controller.currentStep.value == 0) ...[
                _buildStepContent(
                  icon: Icons.favorite_rounded,
                  title: "Health Access",
                  description: "To track your steps and metabolic activity, we need access to HealthKit/Google Fit. This data stays secure.",
                  buttonText: "Grant Access",
                  onPressed: controller.requestHealthPermission,
                ),
              ] else if (controller.currentStep.value == 1) ...[
                _buildStepContent(
                  icon: Icons.location_on_rounded,
                  title: "Location Tagging",
                  description: "Optionally tag your health data with location to see where you were most active. You can choose to skip this.",
                  buttonText: "Enable Location",
                  onPressed: controller.requestLocationPermission,
                ),
              ] else if (controller.currentStep.value == 2) ...[
                _buildStepContent(
                  icon: Icons.camera_alt_rounded,
                  title: "Manual Camera",
                  description: "Used only when you manually take photos of your meals or medical reports. We never access your camera in the background.",
                  buttonText: "Allow Camera",
                  onPressed: controller.requestCameraPermission,
                ),
              ] else ...[
                _buildStepContent(
                  icon: Icons.mic_rounded,
                  title: "Voice Notes",
                  description: "For manual recording of health symptoms or notes. Access is strictly limited to when you press the record button.",
                  buttonText: "Allow Microphone",
                  onPressed: controller.requestMicrophonePermission,
                ),
              ],
              
              const Spacer(),
              TextButton(
                onPressed: controller.skip,
                child: const Text("Maybe later", style: TextStyle(color: Colors.black54)),
              ),
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildStepContent({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(icon, size: 60, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 40),
        Text(
          title,
          style: Get.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Get.textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 60),
        ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      ],
    );
  }
}
