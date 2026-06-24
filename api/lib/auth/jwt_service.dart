import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../config.dart';

class JwtService {
  static SecretKey get _key => SecretKey(Config.jwtSecret);

  /// Emite un token JWT con los datos del usuario.
  static String issue({
    required String userId,
    required String email,
    required bool isAdmin,
  }) {
    final jwt = JWT({
      'sub': userId,
      'email': email,
      'isAdmin': isAdmin,
    });
    return jwt.sign(_key, expiresIn: Duration(days: Config.jwtExpiryDays));
  }

  /// Verifica y decodifica el token. Devuelve null si es inválido o expirado.
  static Map<String, dynamic>? verify(String token) {
    try {
      final jwt = JWT.verify(token, _key);
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Extrae y verifica el token del header Authorization: Bearer <token>.
  static Map<String, dynamic>? fromRequest(Map<String, String> headers) {
    final auth =
        headers['authorization'] ?? headers['Authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) return null;
    return verify(auth.substring(7));
  }

  /// Helper: verifica que el payload tiene isAdmin=true.
  static bool isAdmin(Map<String, dynamic> payload) =>
      payload['isAdmin'] == true;
}
