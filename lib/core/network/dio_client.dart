import 'package:dio/dio.dart';
import 'package:get/get.dart' as get_x;
import '../storage/storage_service.dart';
import '../../services/auth_service.dart';

class DioClient extends get_x.GetxService {
  late Dio _dio;
  final String _baseUrl = 'https://orishub.com/api/';

  Dio get dio => _dio;

  Future<DioClient> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final storage = get_x.Get.find<StorageService>();
        final token = await storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Auto-logout on 401
        if (e.response?.statusCode == 401) {
          get_x.Get.find<AuthService>().logout();
          return handler.next(e);
        }

        // Retry mechanism (1 retry)
        if (_shouldRetry(e)) {
          try {
            final response = await _retry(e.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            return handler.next(e);
          }
        }

        return handler.next(e);
      },
    ));

    return this;
  }

  bool _shouldRetry(DioException e) {
    return e.type != DioExceptionType.cancel &&
        e.response?.statusCode != 401 &&
        (e.requestOptions.extra['retry_count'] ?? 0) < 1;
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    
    requestOptions.extra['retry_count'] = (requestOptions.extra['retry_count'] ?? 0) + 1;

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
