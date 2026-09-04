import 'dart:convert';
import 'package:edfcatalogo_crypto/password_hasher.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../db/mongo_db.dart';
import '../auth/jwt_service.dart';
import 'helpers.dart';

Router authRoutes() {
  final router = Router();

  // POST /api/auth/login
  router.post('/login', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final rawInput = body['emailOrUsername']?.toString().trim() ?? '';
      final password = body['password']?.toString() ?? '';

      if (rawInput.isEmpty || password.isEmpty) {
        return error('emailOrUsername y password son requeridos', 400);
      }

      // Normalizar email a minúsculas; username se respeta tal cual
      final isEmail = rawInput.contains('@');
      final emailOrUsername = isEmail ? rawInput.toLowerCase() : rawInput;

      final coll = await MongoDb.instance.users;

      // Buscar por Email o Username — búsqueda insensible a mayúsculas para email
      final results = <Map<String, dynamic>>[];
      await coll.find({
        r'$or': [
          {'Email': emailOrUsername},
          {'email': emailOrUsername},
          // Búsqueda regex case-insensitive como fallback (cubre emails guardados con mayúsculas)
          {'Email': {r'$regex': '^${RegExp.escape(rawInput)}\$', r'$options': 'i'}},
          {'email': {r'$regex': '^${RegExp.escape(rawInput)}\$', r'$options': 'i'}},
          {'Username': emailOrUsername},
          {'username': emailOrUsername},
        ],
      }).forEach((doc) => results.add(doc.cast<String, dynamic>()));

      if (results.isEmpty) return error('Usuario no encontrado', 401);

      final userDoc = results.first;
      final stored = userDoc['Password']?.toString() ??
          userDoc['password']?.toString() ??
          '';

      if (!PasswordHasher.verify(password, stored)) {
        return error('Contraseña incorrecta', 401);
      }

      // Extraer userId como string
      final rawId = userDoc['_id'];
      final userId = rawId is ObjectId
          ? rawId.oid
          : (rawId is Map ? rawId['\$oid']?.toString() : rawId?.toString()) ??
              '';

      final email =
          userDoc['Email']?.toString() ?? userDoc['email']?.toString() ?? '';
      final role =
          userDoc['Role']?.toString().toLowerCase() ??
          userDoc['role']?.toString().toLowerCase() ??
          '';
      final isAdmin = role == 'admin';

      // Actualizar lastLoginAt (no crítico)
      try {
        final oid = rawId is ObjectId
            ? rawId
            : ObjectId.fromHexString(userId);
        await coll.updateOne(
          where.id(oid),
          modify.set('LastLoginAt', DateTime.now().toUtc()),
        );
      } catch (_) {}

      final token = JwtService.issue(
        userId: userId,
        email: email,
        isAdmin: isAdmin,
      );

      return ok({
        'user': MongoDb.docToJson(userDoc),
        'token': token,
      });
    } catch (e) {
      return error('Error interno: $e', 500);
    }
  });

  // POST /api/auth/refresh — renueva el token sin re-autenticar
  router.post('/refresh', (Request req) async {
    final payload = JwtService.fromRequest(req.headers);
    if (payload == null) return error('Token inválido o expirado', 401);

    final token = JwtService.issue(
      userId: payload['sub'] as String,
      email: payload['email'] as String,
      isAdmin: payload['isAdmin'] as bool? ?? false,
    );
    return ok({'token': token});
  });

  return router;
}
