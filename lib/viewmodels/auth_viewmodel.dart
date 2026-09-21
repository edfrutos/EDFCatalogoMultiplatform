import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/mongo_service.dart';
import '../services/keychain_service.dart';
import '../services/email_service.dart';
import '../services/api_service.dart';

/// ViewModel para gestionar la autenticación de usuarios
class AuthViewModel extends ChangeNotifier {
  final MongoService _mongoService;
  final KeychainService _keychainService;

  /// Los parámetros son opcionales para facilitar los tests con mocks.
  /// En producción se usan las implementaciones reales por defecto.
  AuthViewModel({
    MongoService? mongoService,
    KeychainService? keychainService,
  })  : _mongoService = mongoService ?? MongoService(),
        _keychainService = keychainService ?? KeychainService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Iniciar sesión con email/username y contraseña
  Future<void> signIn({
    required String emailOrUsername,
    required String password,
    bool rememberMe = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validación básica
      if (emailOrUsername.isEmpty || password.isEmpty) {
        _errorMessage = 'Por favor, introduce usuario/email y contraseña';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final user = await _mongoService.authenticateUser(
        emailOrUsername: emailOrUsername,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;

        // Guardar sesión solo si "Recordar contraseña" está marcado
        if (rememberMe) {
          await _keychainService.saveToken(user.email);
          await _keychainService.saveEmail(user.email);
          await _keychainService.saveUserId(user.id);
          // En web persiste el JWT para restaurar la sesión en reinicios
          final jwt = ApiService.instance.currentToken;
          if (jwt != null) await _keychainService.saveJwtToken(jwt);
          print('✅ Sesión guardada para recordar contraseña');
        } else {
          // Limpiar datos guardados si no quiere recordar
          await _keychainService.clearAuthData();
          print('✅ Sesión no guardada (recordar contraseña desactivado)');
        }

        print('✅ Login exitoso para: $emailOrUsername');
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _errorMessage = 'Usuario/email o contraseña incorrectos';
      }
    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = 'Error al conectar con el servidor: $e';
      print('❌ Error en login: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restaurar sesión desde Keychain
  Future<void> restoreSession() async {
    print('🔐 Intentando restaurar sesión...');

    // En web el JWT no sobrevive hot-restart: lo recuperamos del almacenamiento
    // seguro y lo inyectamos en ApiService ANTES de hacer cualquier llamada auth.
    if (kIsWeb) {
      final jwt = await _keychainService.getJwtToken();
      if (jwt != null) {
        ApiService.instance.setToken(jwt);
        print('🔑 JWT restaurado en ApiService desde almacenamiento seguro');
      }
    }

    final userEmail = await _keychainService.getToken();
    if (userEmail == null) {
      print('⚠️ No hay token guardado');
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
      return;
    }

    print('🔑 Email encontrado en Keychain: $userEmail');

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _mongoService.getUserByEmail(userEmail);

      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        print('✅ Sesión restaurada exitosamente para: ${user.email}');
      } else {
        // Usuario no encontrado, limpiar token
        print('⚠️ Usuario no encontrado en MongoDB, limpiando token');
        await _keychainService.clearAuthData();
        _isAuthenticated = false;
        _currentUser = null;
      }
    } catch (e) {
      print('❌ Error al restaurar sesión: $e');
      await _keychainService.clearAuthData();
      _isAuthenticated = false;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recargar usuario actual desde MongoDB
  Future<void> reloadCurrentUser() async {
    final email = _currentUser?.email;
    if (email == null) {
      print('⚠️ No hay usuario actual para recargar');
      return;
    }

    print('🔄 Recargando usuario: $email');

    try {
      final user = await _mongoService.getUserByEmail(email);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        print('✅ Usuario recargado exitosamente');
      } else {
        print('⚠️ Usuario no encontrado al recargar');
      }
    } catch (e) {
      print('❌ Error al recargar usuario: $e');
    }
  }

  /// Cerrar sesión
  void signOut() {
    print(
      '🔐 Cerrando sesión para: ${_currentUser?.email ?? "usuario desconocido"}',
    );

    _keychainService.clearAuthData();
    ApiService.instance.clearToken();

    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;

    notifyListeners();
    print('✅ Sesión cerrada correctamente');
  }

  /// Da de baja la cuenta del usuario actual (requiere reintroducir la contraseña).
  Future<bool> deleteAccount(String password) async {
    final user = _currentUser;
    if (user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deleted = await _mongoService.deleteOwnAccount(
        userId: user.id,
        password: password,
      );
      if (!deleted) {
        _errorMessage =
            'Contraseña incorrecta o no se pudo eliminar la cuenta';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      signOut();
      print('✅ Cuenta eliminada: ${user.email}');
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar la cuenta: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error eliminando cuenta: $e');
      return false;
    }
  }

  /// Registrar nuevo usuario
  Future<bool> register({
    required String username,
    required String name,
    required String email,
    required String password,
  }) async {
    print('📝 Iniciando proceso de registro para: $email');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        // En web /api/users/ es solo para admins: el alta pública pasa por
        // /api/auth/register, que crea el usuario y devuelve el JWT ya autenticado.
        final user = await ApiService.instance.register(
          username: username,
          name: name,
          email: email,
          password: password,
        );

        if (user == null) {
          _errorMessage = 'No se pudo crear la cuenta (¿el email ya existe?)';
          _isLoading = false;
          notifyListeners();
          print('⚠️ Registro fallido para: $email');
          return false;
        }

        _currentUser = user;
        _isAuthenticated = true;
        _isLoading = false;

        await _keychainService.saveToken(user.email);
        await _keychainService.saveEmail(user.email);
        await _keychainService.saveUserId(user.id);
        final jwt = ApiService.instance.currentToken;
        if (jwt != null) await _keychainService.saveJwtToken(jwt);

        notifyListeners();
        print('✅ Registro exitoso para: $email');
        return true;
      }

      // Verificar si el usuario ya existe
      final exists = await _mongoService.checkUserExists(email);
      if (exists) {
        _errorMessage = 'Ya existe una cuenta con este email';
        _isLoading = false;
        notifyListeners();
        print('⚠️ Usuario ya existe: $email');
        return false;
      }

      // Crear usuario en MongoDB
      await _mongoService.createUser(
        username: username,
        name: name,
        email: email,
        password: password,
      );

      // Iniciar sesión automáticamente
      await signIn(emailOrUsername: email, password: password);

      print('✅ Registro exitoso para: $email');
      return true;
    } catch (e) {
      _errorMessage = 'Error al crear la cuenta: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error en registro: $e');
      return false;
    }
  }

  /// Solicitar recuperación de contraseña
  Future<bool> requestPasswordReset(String email) async {
    print('🔑 Solicitando recuperación de contraseña para: $email');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Verificar que el usuario existe
      final exists = await _mongoService.checkUserExists(email);
      if (!exists) {
        _errorMessage = 'No existe una cuenta con este email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Generar token de recuperación (6 dígitos)
      final random = Random();
      final resetToken = random.nextInt(999999).toString().padLeft(6, '0');

      // Guardar token en MongoDB con expiración de 1 hora
      await _mongoService.savePasswordResetToken(email, resetToken);

      // Enviar email con el token
      await EmailService.shared.sendPasswordResetEmail(
        to: email,
        resetToken: resetToken,
      );

      print('✅ Email de recuperación enviado a: $email');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar el email: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error en recuperación: $e');
      return false;
    }
  }

  /// Restablecer contraseña con token
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    print('🔑 Restableciendo contraseña para: $email');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Verificar el token
      final isValid = await _mongoService.verifyPasswordResetToken(
        email,
        token,
      );
      if (!isValid) {
        _errorMessage = 'Código inválido o expirado';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Actualizar contraseña
      await _mongoService.updatePassword(email, newPassword);

      // Limpiar token de recuperación
      try {
        await _mongoService.clearPasswordResetToken(email);
      } catch (_) {
        // Ignorar errores de limpieza
      }

      print('✅ Contraseña restablecida exitosamente para: $email');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al restablecer la contraseña: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error al restablecer contraseña: $e');
      return false;
    }
  }

  /// Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
