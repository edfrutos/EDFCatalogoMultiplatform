import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para gestionar el almacenamiento seguro de credenciales
/// Utiliza Keychain en iOS/macOS y Keystore en Android
class KeychainService {
  static final KeychainService _instance = KeychainService._internal();
  factory KeychainService() => _instance;
  KeychainService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: const LinuxOptions(),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );

  static const String _serviceKey = 'EDFCatalogoMultiplatform';
  static const String _tokenKey = 'authToken';
  static const String _userIdKey = 'userId';
  static const String _emailKey = 'email';

  /// Guardar un valor de forma segura
  Future<bool> set(String key, String value) async {
    try {
      await _storage.write(
        key: '$_serviceKey.$key',
        value: value,
      );
      return true;
    } catch (e) {
      print('❌ Error guardando en almacenamiento seguro: $e');
      return false;
    }
  }

  /// Obtener un valor de forma segura
  Future<String?> get(String key) async {
    try {
      return await _storage.read(key: '$_serviceKey.$key');
    } catch (e) {
      print('❌ Error leyendo del almacenamiento seguro: $e');
      return null;
    }
  }

  /// Eliminar un valor de forma segura
  Future<bool> remove(String key) async {
    try {
      await _storage.delete(key: '$_serviceKey.$key');
      return true;
    } catch (e) {
      print('❌ Error eliminando del almacenamiento seguro: $e');
      return false;
    }
  }

  /// Limpiar todo el almacenamiento seguro
  Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      print('❌ Error limpiando almacenamiento seguro: $e');
      return false;
    }
  }

  // MARK: - Token Management

  /// Guardar el token de autenticación
  Future<bool> saveToken(String token) async {
    print('🔑 Guardando token en almacenamiento seguro');
    final success = await set(_tokenKey, token);
    if (success) {
      print('✅ Token guardado exitosamente');
    } else {
      print('❌ Error al guardar token');
    }
    return success;
  }

  /// Obtener el token de autenticación
  Future<String?> getToken() async {
    print('🔑 Obteniendo token del almacenamiento seguro');
    final token = await get(_tokenKey);
    if (token != null) {
      print('✅ Token encontrado');
    } else {
      print('⚠️ No se encontró token');
    }
    return token;
  }

  /// Eliminar el token de autenticación
  Future<bool> deleteToken() async {
    print('🔑 Eliminando token del almacenamiento seguro');
    final success = await remove(_tokenKey);
    if (success) {
      print('✅ Token eliminado exitosamente');
    } else {
      print('⚠️ No se pudo eliminar el token (puede que no existiera)');
    }
    return success;
  }

  // MARK: - User Info Management

  /// Guardar ID de usuario
  Future<bool> saveUserId(String userId) async {
    return await set(_userIdKey, userId);
  }

  /// Obtener ID de usuario
  Future<String?> getUserId() async {
    return await get(_userIdKey);
  }

  /// Guardar email de usuario
  Future<bool> saveEmail(String email) async {
    return await set(_emailKey, email);
  }

  /// Obtener email de usuario
  Future<String?> getEmail() async {
    return await get(_emailKey);
  }

  /// Limpiar toda la información de autenticación
  Future<void> clearAuthData() async {
    await deleteToken();
    await remove(_userIdKey);
    await remove(_emailKey);
  }
}

