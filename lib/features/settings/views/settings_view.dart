import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildProfileTile(),
          const SizedBox(height: 32),
          _buildSectionTitle("App Settings"),
          _buildSettingsTile(Icons.security_rounded, "Manage Permissions", () => openAppSettings()),
          _buildSettingsTile(Icons.history_toggle_off_rounded, "View Sync Logs", () => Get.toNamed('/sync-logs')),
          _buildSettingsTile(Icons.notifications_outlined, "Notifications", null),
          _buildSettingsTile(Icons.lock_outline, "Privacy & Security", null),
          const SizedBox(height: 32),
          _buildSectionTitle("Account"),
          _buildSettingsTile(
            Icons.logout_rounded, 
            "Logout", 
            authService.logout,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("User Name", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("user@example.com", style: TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback? onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color ?? AppTheme.primaryColor),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
