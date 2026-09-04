import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../lib/config.dart';
import '../lib/db/mongo_db.dart';
import '../lib/routes/auth_routes.dart';
import '../lib/routes/user_routes.dart';
import '../lib/routes/catalog_routes.dart';
import '../lib/routes/s3_routes.dart';
import '../lib/routes/contact_routes.dart';

void main() async {
  // Validar configuración crítica
  if (Config.mongoUri.isEmpty || Config.mongoDb.isEmpty) {
    stderr.writeln('❌ Error: MONGO_URI y MONGO_DB deben estar en el entorno');
    exit(1);
  }

  // Conectar a MongoDB
  try {
    await MongoDb.instance.connect();
  } catch (e) {
    stderr.writeln('❌ Error conectando a MongoDB: $e');
    exit(1);
  }

  // Construir router
  final router = Router();

  // Health check (sin auth)
  router.get('/health', (_) => Response.ok(
        '{"status":"ok","service":"edfcatalogo-api"}',
        headers: {'Content-Type': 'application/json'},
      ));

  // Montar rutas bajo /api/
  router.mount('/api/auth/', authRoutes().call);
  router.mount('/api/users/', userRoutes().call);
  router.mount('/api/catalogs/', catalogRoutes().call);
  router.mount('/api/s3/', s3Routes().call);
  router.mount('/api/contact/', contactRoutes().call);

  // 404 catch-all
  router.all('/<ignored|.*>', (_) => Response.notFound(
        '{"error":"Ruta no encontrada"}',
        headers: {'Content-Type': 'application/json'},
      ));

  // Pipeline: CORS → logging → router
  final corsOrigin = Config.corsOrigin;
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: corsOrigin,
        ACCESS_CONTROL_ALLOW_HEADERS:
            'Content-Type, Authorization, X-File-Name, X-Folder, X-User-Id, X-Catalog-Id, X-File-Type',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_MAX_AGE: '86400',
      }))
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, '0.0.0.0', Config.port);
  print('🚀 EDF Catálogo API en http://${server.address.host}:${server.port}');
  print('   MongoDB: ${Config.mongoDb}');
  print('   CORS origin: $corsOrigin');
}
