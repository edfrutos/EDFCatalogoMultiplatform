import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

/// Servicio para gestionar el almacenamiento seguro de credenciales
/// Utiliza Keychain en iOS/macOS y Keystore en Android
/// Fallback a SharedPreferences si Keychain falla (especialmente en macOS sin certificado)
class KeychainService {
  static final KeychainService _instance = KeychainService._internal();
  factory KeychainService() => _instance;
  KeychainService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // Para desarrollo sin certificado, no especificamos groupId
      // Esto permite usar Keychain sin necesidad de signing
    ),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  // Flag para usar fallback cuando Keychain falla
  bool _useFallback = false;

  static const String _serviceKey = 'EDFCatalogoMultiplatform';
  static const String _tokenKey = 'authToken';
  static const String _userIdKey = 'userId';
  static const String _emailKey = 'email';

  /// Guardar un valor de forma segura (con fallback a SharedPreferences)
  Future<bool> set(String key, String value) async {
    final fullKey = '$_serviceKey.$key';

    // Intentar con Keychain primero (a menos que ya estemos en fallback)
    if (!_useFallback) {
      try {
        await _storage.write(key: fullKey, value: value);
        print('✅ Valor guardado en Keychain');
        return true;
      } catch (e) {
        // Solo loguear una vez para evitar spam
        if (!_useFallback) {
          print('⚠️ Keychain no disponible, intentando SharedPreferences...');
        }
        _useFallback = true;
      }
    }

    // Fallback a SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(fullKey, value);
      if (success) {
        print('✅ Valor guardado en SharedPreferences (fallback)');
      }
      return success;
    } catch (e) {
      // En desarrollo sin certificado, ambos pueden fallar
      // No es crítico - simplemente no se guardará la sesión
      if (Platform.isMacOS) {
        // En macOS, si ambos fallan, simplemente no guardar
        // El usuario tendrá que iniciar sesión cada vez en desarrollo
        print(
          '⚠️ No se pudo guardar (Keychain y SharedPreferences no disponibles en desarrollo)',
        );
        return false;
      }
      print('❌ Error guardando en SharedPreferences: $e');
      return false;
    }
  }

  /// Obtener un valor de forma segura (con fallback a SharedPreferences)
  Future<String?> get(String key) async {
    final fullKey = '$_serviceKey.$key';

    // Intentar con Keychain primero (a menos que ya estemos en fallback)
    if (!_useFallback) {
      try {
        final value = await _storage.read(key: fullKey);
        if (value != null) return value;
        // Si Keychain no tiene valor, verificar SharedPreferences también
        // (puede que se haya guardado allí en un fallback anterior)
        try {
          final prefs = await SharedPreferences.getInstance();
          final fallbackValue = prefs.getString(fullKey);
          if (fallbackValue != null) {
            print('📋 Valor encontrado en SharedPreferences (fallback)');
            return fallbackValue;
          }
        } catch (_) {
          // Ignorar errores silenciosamente en este punto
        }
        return null;
      } catch (e) {
        // Solo loguear una vez para evitar spam
        if (!_useFallback) {
          print('⚠️ Keychain no disponible, intentando SharedPreferences...');
        }
        _useFallback = true;
      }
    }

    // Fallback a SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(fullKey);
    } catch (e) {
      // En desarrollo sin certificado, ambos pueden fallar
      // No es crítico - simplemente el usuario tendrá que iniciar sesión cada vez
      if (Platform.isMacOS) {
        // Silencioso en macOS para evitar spam de logs
        return null;
      }
      print('⚠️ Error leyendo de SharedPreferences: $e');
      return null;
    }
  }

  /// Eliminar un valor de forma segura (con fallback a SharedPreferences)
  Future<bool> remove(String key) async {
    final fullKey = '$_serviceKey.$key';

    // Intentar con Keychain primero
    if (!_useFallback) {
      try {
        await _storage.delete(key: fullKey);
        // También eliminar de SharedPreferences por si acaso
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(fullKey);
        } catch (_) {}
        return true;
      } catch (e) {
        print('⚠️ Error eliminando de Keychain, usando fallback: $e');
        _useFallback = true;
      }
    }

    // Fallback a SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(fullKey);
    } catch (e) {
      print('❌ Error eliminando de SharedPreferences: $e');
      return false;
    }
  }

  /// Limpiar todo el almacenamiento seguro (con fallback a SharedPreferences)
  Future<bool> clearAll() async {
    // Limpiar Keychain
    if (!_useFallback) {
      try {
        await _storage.deleteAll();
      } catch (e) {
        print('⚠️ Error limpiando Keychain: $e');
        _useFallback = true;
      }
    }

    // Limpiar SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      // Eliminar solo las claves que empiezan con nuestro servicio
      final keys = prefs.getKeys();
      final keysToRemove = keys.where((k) => k.startsWith(_serviceKey));
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      return true;
    } catch (e) {
      print('❌ Error limpiando SharedPreferences: $e');
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
      // No loguear como error si simplemente no hay token guardado
      // (es normal en la primera ejecución o si el almacenamiento no está disponible)
      print('⚠️ No hay token guardado');
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
