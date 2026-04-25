import 'package:get/get.dart';
import '../core/network/dio_client.dart';
import '../core/storage/storage_service.dart';

class AuthService extends GetxService {
  final _storage = Get.find<StorageService>();
  final _dio = Get.find<DioClient>();

  final isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    isLoggedIn.value = _storage.isLoggedIn();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.dio.post(
        'auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Extract token (support multiple key names)
        final token = response.data['access_token'] ?? response.data['token'];

        if (token != null) {
          // Extract user ID (support multiple key names)

          final userId =
              data['admin']?['user_id']?.toString() ??
                  data['admin']?['id']?.toString();
          // Save authentication data
          await _storage.saveToken(token);
          if (userId != null) {
            await _storage.saveUserId(userId);
          }
          await _storage.saveUserEmail(email);
          await _storage.setLoggedIn(true);
          isLoggedIn.value = true;
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAuth();
    isLoggedIn.value = false;
    Get.offAllNamed('/login');
  }
}
