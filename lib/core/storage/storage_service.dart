import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService extends GetxService {
  final _storage = GetStorage();
  final _secureStorage = const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keySyncLogs = 'sync_logs';
  static const String _keyDeviceId = 'device_id';

  Future<StorageService> init() async {
    await GetStorage.init();
    return this;
  }

  // token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _keyToken);
  }

  // user id
  Future<void> saveUserId(String userId) async {
    await _storage.write(_keyUserId, userId);
  }

  String? getUserId() => _storage.read(_keyUserId);

  // user email
  Future<void> saveUserEmail(String email) async {
    await _storage.write(_keyUserEmail, email);
  }

  String? getUserEmail() => _storage.read(_keyUserEmail);

  // device id (persistent, app-scoped)
  Future<String?> getDeviceId() async {
    String? id = _storage.read(_keyDeviceId);

    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(_keyDeviceId, id);
    }

    return id;
  }

  // auth state
  Future<void> setLoggedIn(bool value) =>
      _storage.write(_keyIsLoggedIn, value);

  bool isLoggedIn() => _storage.read(_keyIsLoggedIn) ?? false;

  // sync time
  Future<void> saveLastSync(DateTime time) =>
      _storage.write(_keyLastSync, time.toIso8601String());

  DateTime? getLastSync() {
    final timeStr = _storage.read(_keyLastSync);
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }

  // logs
  Future<void> addSyncLog(bool success, String message) async {
    List<dynamic> logs = _storage.read(_keySyncLogs) ?? [];

    logs.insert(0, {
      'timestamp': DateTime.now().toIso8601String(),
      'success': success,
      'message': message,
    });

    if (logs.length > 50) logs = logs.sublist(0, 50);

    await _storage.write(_keySyncLogs, logs);
  }

  List<Map<String, dynamic>> getSyncLogs() {
    final List<dynamic> logs = _storage.read(_keySyncLogs) ?? [];
    return logs.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // clear auth
  Future<void> clearAuth() async {
    await _secureStorage.delete(key: _keyToken);
    await _storage.write(_keyIsLoggedIn, false);
    await _storage.remove(_keySyncLogs);
  }
}