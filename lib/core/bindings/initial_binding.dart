import 'package:get/get.dart';
import '../network/dio_client.dart';
import '../storage/storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/health_service.dart';
import '../controllers/lifecycle_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(StorageService());
    Get.put(DioClient());
    Get.put(AuthService());
    Get.put(HealthService());
    Get.put(LifecycleController());
  }
}
