import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../db/mongo_db.dart';
import '../auth/jwt_service.dart';
import 'helpers.dart';

Router catalogRoutes() {
  final router = Router();

  // GET /api/catalogs?userId=&isAdmin=true&userEmail=
  router.get('/', (Request req) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    final params = req.url.queryParameters;
    final userId = params['userId'] ?? payload['sub'] as String;
    final isAdmin = params['isAdmin'] == 'true' || JwtService.isAdmin(payload);
    final userEmail = params['userEmail'] ?? payload['email'] as String? ?? '';

    try {
      final coll = await MongoDb.instance.catalogs;
      final selector = isAdmin
          ? <String, dynamic>{}
          : {
              r'$or': [
                {'Owner': userId},
                {'CreatedBy': userId},
                {'userId': userId},
                if (userEmail.isNotEmpty) {'Owner': userEmail},
                if (userEmail.isNotEmpty) {'CreatedBy': userEmail},
              ],
            };

      final docs = <Map<String, dynamic>>[];
      await coll
          .find(selector)
          .forEach((doc) => docs.add(doc.cast<String, dynamic>()));

      return ok({'catalogs': docs.map(MongoDb.docToJson).toList()});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // GET /api/catalogs/<id>
  router.get('/<id>', (Request req, String id) async {
    if (requireAuth(req) == null) return error('No autorizado', 401);
    try {
      final coll = await MongoDb.instance.catalogs;
      final oid = ObjectId.fromHexString(id);
      final doc = await coll.findOne(where.id(oid));
      if (doc == null) return error('Catálogo no encontrado', 404);
      return ok(MongoDb.docToJson(doc.cast<String, dynamic>()));
    } catch (e) {
      return error('$e', 500);
    }
  });

  // POST /api/catalogs — crear catálogo
  router.post('/', (Request req) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final coll = await MongoDb.instance.catalogs;
      final now = DateTime.now().toUtc();

      // Construir documento con las mayúsculas de MongoDB del proyecto
      final doc = {
        'Name': body['name']?.toString() ??
            body['Name']?.toString() ??
            'Nuevo catálogo',
        'Description': body['description']?.toString() ??
            body['Description']?.toString() ??
            '',
        'Owner': body['owner']?.toString() ??
            body['Owner']?.toString() ??
            payload['email'],
        'CreatedBy': body['createdBy']?.toString() ??
            body['CreatedBy']?.toString() ??
            payload['sub'],
        'Headers': body['columns'] ??
            body['Headers'] ??
            body['columns'] ??
            <dynamic>[],
        'Rows': body['rows'] ?? body['Rows'] ?? <dynamic>[],
        'ThumbnailUrl':
            body['thumbnailUrl']?.toString() ??
            body['ThumbnailUrl']?.toString() ??
            '',
        'CreatedAt': now,
        'UpdatedAt': now,
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

  // PUT /api/catalogs/<id> — actualizar campos sueltos
  router.put('/<id>', (Request req, String id) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    try {
      final body =
          jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final oid = ObjectId.fromHexString(id);
      final coll = await MongoDb.instance.catalogs;

      // Construir $set desde el body (acepta camelCase o PascalCase)
      final updates = <String, dynamic>{'UpdatedAt': DateTime.now().toUtc()};
      void setField(String pascal, String camel) {
        if (body.containsKey(pascal)) updates[pascal] = body[pascal];
        if (body.containsKey(camel)) updates[pascal] = body[camel];
      }

      setField('Name', 'name');
      setField('Description', 'description');
      setField('Headers', 'columns');
      setField('Rows', 'rows');
      setField('ThumbnailUrl', 'thumbnailUrl');
      setField('Owner', 'owner');

      // También acepta body completo tipo objeto Catalog serializado
      if (body.containsKey('id') || body.containsKey('_id')) {
        // Objeto completo — usar todos los campos relevantes
        if (body['name'] != null || body['Name'] != null) {
          updates['Name'] = body['name'] ?? body['Name'];
        }
        if (body['description'] != null || body['Description'] != null) {
          updates['Description'] = body['description'] ?? body['Description'];
        }
        if (body['columns'] != null || body['Headers'] != null) {
          updates['Headers'] = body['columns'] ?? body['Headers'];
        }
        if (body['rows'] != null || body['Rows'] != null) {
          updates['Rows'] = body['rows'] ?? body['Rows'];
        }
        if (body['thumbnailUrl'] != null || body['ThumbnailUrl'] != null) {
          updates['ThumbnailUrl'] =
              body['thumbnailUrl'] ?? body['ThumbnailUrl'];
        }
      }

      final result = await coll.updateOne(where.id(oid), {r'$set': updates});
      return ok({'updated': result.nModified > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  // DELETE /api/catalogs/<id>
  router.delete('/<id>', (Request req, String id) async {
    final payload = requireAuth(req);
    if (payload == null) return error('No autorizado', 401);

    try {
      final coll = await MongoDb.instance.catalogs;
      final oid = ObjectId.fromHexString(id);
      final result = await coll.deleteOne(where.id(oid));
      return ok({'deleted': result.nRemoved > 0});
    } catch (e) {
      return error('$e', 500);
    }
  });

  return router;
}
