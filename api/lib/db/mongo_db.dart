import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import '../config.dart';

/// Conexión singleton a MongoDB Atlas.
class MongoDb {
  static final MongoDb instance = MongoDb._();
  MongoDb._();

  Db? _db;

  Future<void> connect() async {
    if (_db != null && _db!.isConnected) return;
    if (Config.mongoUri.isEmpty || Config.mongoDb.isEmpty) {
      throw StateError('MONGO_URI y MONGO_DB deben estar en el entorno');
    }

    // Asegurar que el URI incluye el nombre de la base de datos.
    // MongoDB Atlas URI típico: mongodb+srv://user:pass@host/
    // → necesita quedar: mongodb+srv://user:pass@host/edf_catalogotablas
    String uri = Config.mongoUri.trim();
    final dbName = Config.mongoDb.trim();

    // Extraer la parte sin query string para no romper params como retryWrites
    final qIdx = uri.indexOf('?');
    final base = qIdx >= 0 ? uri.substring(0, qIdx) : uri;
    final query = qIdx >= 0 ? uri.substring(qIdx) : '';

    final endsWithSlash = base.endsWith('/');
    final slashIdx = base.lastIndexOf('/');
    // La última parte del path es el nombre de BD; si está vacío o es 'test', sustituir
    final currentDb = endsWithSlash
        ? ''
        : base.substring(slashIdx + 1);

    if (currentDb.isEmpty || currentDb == 'test') {
      final cleanBase = endsWithSlash ? base : base.substring(0, slashIdx + 1);
      uri = '$cleanBase$dbName$query';
    }

    _db = await Db.create(uri);
    await _db!.open();
    print('📦 MongoDB conectado → ${_db!.databaseName}');
  }

  Future<Db> get database async {
    if (_db == null || !_db!.isConnected) await connect();
    return _db!;
  }

  Future<DbCollection> collection(String name) async {
    final db = await database;
    return db.collection(name);
  }

  Future<DbCollection> get users => collection('users');
  Future<DbCollection> get catalogs => collection('catalogs');

  // ── Serialización JSON ────────────────────────────────────────────────────

  /// Convierte un valor MongoDB a un tipo JSON serializable:
  ///   ObjectId  → { "$oid": "..." }
  ///   DateTime  → "2024-01-01T00:00:00.000Z"
  ///   Map/List  → recursivo
  static dynamic toJson(dynamic value) {
    if (value == null) return null;
    if (value is ObjectId) return {'\$oid': value.oid};
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return {
        for (final e in value.entries) e.key.toString(): toJson(e.value),
      };
    }
    if (value is List) return value.map(toJson).toList();
    return value;
  }

  static Map<String, dynamic> docToJson(Map<String, dynamic> doc) =>
      toJson(doc) as Map<String, dynamic>;

  static String encodeDoc(Map<String, dynamic> doc) =>
      jsonEncode(docToJson(doc));

  static String encodeList(List<Map<String, dynamic>> docs) =>
      jsonEncode(docs.map(docToJson).toList());
}
