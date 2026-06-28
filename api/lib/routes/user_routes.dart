import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../db/mongo_db.dart';
import '../auth/jwt_service.dart';
import 'helpers.dart';

Router userRoutes() {
  final router = Router();

  // GET /api/users — lista todos (admin)
  router.get('/', (Request req) async {
    if (requireAdmin(req) == null) return error('No autorizado', 401);
    try {
      final coll = await MongoDb.instance.users;
      final docs = <Map<String, dynamic>>[];
      await coll.find().forEach((doc) => docs.add(doc.cast<String, dynamic>()));
      return ok({'users': docs.map(MongoDb.docToJson).toList()});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // GET /api/users/stats — estadísticas (admin)
  router.get('/stats', (Request req) async {
    if (requireAdmin(req) == null) return error('No autorizado', 401);
    try {
      final coll = await MongoDb.instance.users;
      final total = await coll.count();
      final admins = await coll.count(
        where.eq('Role', 'admin').or(where.eq('role', 'admin')),
      );
      return ok({'total': total, 'admins': admins, 'regular': total - admins});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // GET /api/users/by-email/<email>
  router.get('/by-email/<email>', (Request req, String encodedEmail) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    final email = Uri.decodeComponent(encodedEmail);
    try {
      final coll = await MongoDb.instance.users;
      final doc = await coll.findOne({
        r'$or': [{'Email': email}, {'email': email}],
      });
      if (doc == null) return error('Usuario no encontrado', 404);
      return ok(MongoDb.docToJson(doc.cast<String, dynamic>()));
    } catch (e) {
      return error('$e', 500);
    }
  });

  // GET /api/users/<id>
  router.get('/<id>', (Request req, String id) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    try {
      final coll = await MongoDb.instance.users;
      final oid = ObjectId.fromHexString(id);
      final doc = await coll.findOne(where.id(oid));
      if (doc == null) return error('Usuario no encontrado', 404);
      return ok(MongoDb.docToJson(doc.cast<String, dynamic>()));
    } catch (e) {
      return error('$e', 500);
    }
  });

  // POST /api/users/check-exists — verifica si un email ya existe
  router.post('/check-exists', (Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email']?.toString().trim() ?? '';
      if (email.isEmpty) return error('email requerido', 400);

      final coll = await MongoDb.instance.users;
      final count = await coll.count(
        where.eq('Email', email).or(where.eq('email', email)),
      );
      return ok({'exists': count > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // POST /api/users — crear usuario (admin)
  router.post('/', (Request req) async {
    if (requireAdmin(req) == null) return error('No autorizado', 401);
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      // Normalizar email a minúsculas para evitar duplicados y fallos de login
      final email = (body['email']?.toString().trim() ?? '').toLowerCase();
      final username = body['username']?.toString().trim() ?? '';
      final name = body['name']?.toString().trim() ?? '';
      final password = body['password']?.toString() ?? '';
      final role = body['role']?.toString() ?? 'user';

      if (email.isEmpty || username.isEmpty || password.isEmpty) {
        return error('email, username y password son requeridos', 400);
      }

      final coll = await MongoDb.instance.users;

      // Comprobar duplicados
      final exists = await coll.count(
        where.eq('Email', email).or(where.eq('email', email)),
      );
      if (exists > 0) return error('El email ya está registrado', 409);

      // Hash SHA-256
      final passwordHash =
          base64Encode(sha256.convert(utf8.encode(password)).bytes);

      final doc = {
        'Email': email,
        'Username': username,
        'Name': name,
        'Password': passwordHash,
        'Role': role,
        'FullName': body['fullName']?.toString() ?? '',
        'Phone': body['phone']?.toString() ?? '',
        'Company': body['company']?.toString() ?? '',
        'Address': body['address']?.toString() ?? '',
        'Occupation': body['occupation']?.toString() ?? '',
        'ProfileImageUrl': body['profileImageUrl']?.toString() ?? '',
        'IsActive': true,
        'CreatedAt': DateTime.now().toUtc(),
      };

      final result = await coll.insertOne(doc);
      final inserted = doc..['_id'] = result.id;
      return Response(
        201,
        body: MongoDb.encodeDoc(inserted.cast<String, dynamic>()),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return error('$e', 500);
    }
  });

  // PUT /api/users/<id> — actualizar usuario
  router.put('/<id>', (Request req, String id) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    // Solo admins pueden cambiar el rol; usuarios normales solo se editan a sí mismos
    final callerIsAdmin = JwtService.isAdmin(payload);
    if (!callerIsAdmin && payload['sub'] != id) {
      return error('No autorizado para editar este usuario', 403);
    }

    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final oid = ObjectId.fromHexString(id);
      final coll = await MongoDb.instance.users;

      // Construir modificador con campos permitidos
      final updates = <String, dynamic>{};
      const directFields = [
        'Name', 'FullName', 'Phone', 'Company', 'Address',
        'Occupation', 'ProfileImageUrl', 'IsActive',
      ];
      for (final f in directFields) {
        if (body.containsKey(f.toLowerCase())) {
          updates[f] = body[f.toLowerCase()];
        }
        if (body.containsKey(f)) {
          updates[f] = body[f];
        }
      }
      // Solo admins pueden cambiar rol
      if (callerIsAdmin && body.containsKey('role')) {
        updates['Role'] = body['role'];
      }
      // Cambio de contraseña
      if (body.containsKey('password') &&
          body['password'].toString().isNotEmpty) {
        updates['Password'] = base64Encode(
          sha256.convert(utf8.encode(body['password'].toString())).bytes,
        );
      }

      if (updates.isEmpty) return error('Sin campos para actualizar', 400);
      updates['UpdatedAt'] = DateTime.now().toUtc();

      final result = await coll.updateOne(
        where.id(oid),
        {r'$set': updates},
      );
      return ok({'updated': result.nModified > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // DELETE /api/users/<id> — eliminar usuario (admin)
  router.delete('/<id>', (Request req, String id) async {
    if (requireAdmin(req) == null) return error('No autorizado', 401);
    try {
      final coll = await MongoDb.instance.users;
      final oid = ObjectId.fromHexString(id);
      final result = await coll.deleteOne(where.id(oid));
      return ok({'deleted': result.nRemoved > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // POST /api/users/password/reset-token
  router.post('/password/reset-token', (Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email']?.toString().trim() ?? '';
      final token = body['token']?.toString() ?? '';
      if (email.isEmpty || token.isEmpty) {
        return error('email y token son requeridos', 400);
      }

      final coll = await MongoDb.instance.users;
      final result = await coll.updateOne(
        {r'$or': [{'Email': email}, {'email': email}]},
        {
          r'$set': {
            'PasswordResetToken': token,
            'PasswordResetExpiry':
                DateTime.now().toUtc().add(const Duration(hours: 1)),
          },
        },
      );
      return ok({'saved': result.nModified > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // POST /api/users/password/verify-token
  router.post('/password/verify-token', (Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email']?.toString().trim() ?? '';
      final token = body['token']?.toString() ?? '';

      final coll = await MongoDb.instance.users;
      final doc = await coll.findOne(
        {r'$or': [{'Email': email}, {'email': email}]},
      );
      if (doc == null) return ok({'valid': false});

      final stored =
          doc['PasswordResetToken']?.toString() ?? '';
      final expiry = doc['PasswordResetExpiry'];
      final expiryDate = expiry is DateTime
          ? expiry
          : (expiry is String ? DateTime.tryParse(expiry) : null);

      final valid = stored == token &&
          expiryDate != null &&
          DateTime.now().toUtc().isBefore(expiryDate);
      return ok({'valid': valid});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // PUT /api/users/password — actualizar contraseña con token
  router.put('/password', (Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email']?.toString().trim() ?? '';
      final newPassword = body['newPassword']?.toString() ?? '';

      if (email.isEmpty || newPassword.isEmpty) {
        return error('email y newPassword son requeridos', 400);
      }

      final coll = await MongoDb.instance.users;
      final passwordHash =
          base64Encode(sha256.convert(utf8.encode(newPassword)).bytes);

      final result = await coll.updateOne(
        {r'$or': [{'Email': email}, {'email': email}]},
        {
          r'$set': {'Password': passwordHash},
          r'$unset': {'PasswordResetToken': '', 'PasswordResetExpiry': ''},
        },
      );
      return ok({'updated': result.nModified > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // DELETE /api/users/password/token — eliminar token de reset
  router.delete('/password/token', (Request req) async {
    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = body['email']?.toString().trim() ?? '';
      if (email.isEmpty) return error('email requerido', 400);

      final coll = await MongoDb.instance.users;
      await coll.updateOne(
        {r'$or': [{'Email': email}, {'email': email}]},
        {r'$unset': {'PasswordResetToken': '', 'PasswordResetExpiry': ''}},
      );
      return ok({'cleared': true});
    } catch (e) {
      return error('$e', 500);
    }
  });

  return router;
}
