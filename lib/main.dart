import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bindings/auth_binding.dart';
import 'features/auth/views/login_view.dart';
import 'features/dashboard/bindings/dashboard_binding.dart';
import 'features/dashboard/views/dashboard_view.dart';
import 'features/permissions/bindings/permissions_binding.dart';
import 'features/permissions/views/permissions_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/settings/views/sync_logs_view.dart';
import 'features/settings/views/submissions_view.dart';
import 'services/auth_service.dart';
import 'services/background_sync_service.dart';
import 'services/submissions_service.dart';
import 'core/storage/storage_service.dart';
import 'core/network/dio_client.dart';
import 'core/controllers/lifecycle_controller.dart';
import 'services/health_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => DioClient().init());
  Get.put(AuthService());
  Get.put(HealthService());
  Get.put(LocationService());
  Get.put(SubmissionsService());
  Get.put(LifecycleController());

  // Initialize Background Service
  await BackgroundSyncService.initialize();

  runApp(const HealthSyncApp());
}

class HealthSyncApp extends StatelessWidget {
  const HealthSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Sync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return SafeArea(child: child!);
      },
      debugShowMaterialGrid: false,
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginView(),
          binding: AuthBinding(),
        ),
        GetPage(
          name: '/permissions',
          page: () => const PermissionsView(),
          binding: PermissionsBinding(),
        ),
        GetPage(
          name: '/dashboard',
          page: () => const DashboardView(),
          binding: DashboardBinding(),
        ),
        GetPage(
          name: '/settings',
          page: () => const SettingsView(),
        ),
        GetPage(
          name: '/sync-logs',
          page: () => const SyncLogsView(),
        ),
        GetPage(
          name: '/submissions',
          page: () => const SubmissionsView(),
        ),
      ],
      initialRoute: _getInitialRoute(),
    );
  }

  String _getInitialRoute() {
    final authService = Get.find<AuthService>();
    return authService.isLoggedIn.value ? '/dashboard' : '/login';
  }
}
