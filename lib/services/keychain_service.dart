import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de almacenamiento seguro de credenciales.
///
/// Plataformas:
///   iOS/macOS → Keychain del sistema (Security.framework)
///   Android   → EncryptedSharedPreferences (AES-256)
///   Linux     → Secret Service API (libsecret)
///   Windows   → DPAPI
///   Web       → localStorage con cifrado AES de flutter_secure_storage
///               ⚠️ Web no ofrece aislamiento real a nivel SO; usar solo como
///               último recurso y nunca almacenar tokens de larga duración.
///
/// SEGURIDAD: este servicio NO hace fallback a SharedPreferences (texto plano).
/// Si el almacenamiento seguro no está disponible, las operaciones devuelven
/// false/null y el usuario deberá iniciar sesión de nuevo en el siguiente arranque.
/// Esto es correcto: es mejor perder la sesión que exponer credenciales.
class KeychainService {
  static final KeychainService _instance = KeychainService._internal();
  factory KeychainService() => _instance;
  KeychainService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // AES-256 vía Jetpack Security
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      // useDataProtectionKeychain: false → permite usar el Keychain sin
      // el entitlement "Keychain Sharing", lo que facilita el desarrollo
      // sin certificado de distribución. En producción con signing completo
      // cambiar a true para mayor aislamiento.
      useDataProtectionKeychain: false,
    ),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const String _serviceKey = 'EDFCatalogoMultiplatform';
  static const String _tokenKey = 'authToken';
  static const String _userIdKey = 'userId';
  static const String _emailKey = 'email';

  // ---------------------------------------------------------------------------
  // Primitivas seguras (sin fallback a texto plano)
  // ---------------------------------------------------------------------------

  /// Guarda [value] bajo [key] en el almacenamiento seguro de la plataforma.
  /// Devuelve false si el almacenamiento no está disponible (p.ej. macOS sin
  /// signing en desarrollo). La app debe tolerar este caso sin crashear.
  Future<bool> set(String key, String value) async {
    final fullKey = '$_serviceKey.$key';
    try {
      await _storage.write(key: fullKey, value: value);
      return true;
    } catch (e) {
      _logStorageError('set', key, e);
      return false;
    }
  }

  /// Lee [key] del almacenamiento seguro. Devuelve null si no existe o falla.
  Future<String?> get(String key) async {
    final fullKey = '$_serviceKey.$key';
    try {
      return await _storage.read(key: fullKey);
    } catch (e) {
      _logStorageError('get', key, e);
      return null;
    }
  }

  /// Elimina [key] del almacenamiento seguro. Devuelve false si falla.
  Future<bool> remove(String key) async {
    final fullKey = '$_serviceKey.$key';
    try {
      await _storage.delete(key: fullKey);
      return true;
    } catch (e) {
      _logStorageError('remove', key, e);
      return false;
    }
  }

  /// Elimina todas las claves con prefijo del servicio.
  Future<bool> clearAll() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_serviceKey)) {
          await _storage.delete(key: key);
        }
      }
      return true;
    } catch (e) {
      _logStorageError('clearAll', '*', e);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Token de autenticación
  // ---------------------------------------------------------------------------

  Future<bool> saveToken(String token) async {
    print('🔑 Guardando token en almacenamiento seguro');
    final ok = await set(_tokenKey, token);
    print(ok ? '✅ Token guardado' : '❌ No se pudo guardar el token');
    return ok;
  }

  Future<String?> getToken() async {
    final token = await get(_tokenKey);
    print(token != null ? '✅ Token recuperado' : '⚠️ No hay token guardado');
    return token;
  }

  Future<bool> deleteToken() async {
    print('🔑 Eliminando token');
    final ok = await remove(_tokenKey);
    print(ok ? '✅ Token eliminado' : '⚠️ No se pudo eliminar el token (puede que no existiera)');
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Datos de usuario
  // ---------------------------------------------------------------------------

  Future<bool> saveUserId(String userId) => set(_userIdKey, userId);
  Future<String?> getUserId() => get(_userIdKey);

  Future<bool> saveEmail(String email) => set(_emailKey, email);
  Future<String?> getEmail() => get(_emailKey);

  /// Elimina token + userId + email en una sola operación (logout completo).
  Future<void> clearAuthData() async {
    await Future.wait([
      remove(_tokenKey),
      remove(_userIdKey),
      remove(_emailKey),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _logStorageError(String op, String key, Object e) {
    if (kIsWeb) {
      print('⚠️ KeychainService[$op/$key] Web: $e');
    } else {
      print('⚠️ KeychainService[$op/$key]: $e');
      print('   En macOS/desarrollo sin certificado es normal que el Keychain '
          'no esté disponible. La sesión no se persistirá.');
    }
  }
}
