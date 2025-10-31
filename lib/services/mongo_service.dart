import 'package:mongo_dart/mongo_dart.dart';
import '../utils/env_config.dart';
import '../models/user.dart';
import '../models/catalog.dart';

/// Servicio para gestionar la conexión y operaciones con MongoDB
class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  Db? _db;
  bool _isConnecting = false;
  String? _connectionUri;

  /// Obtener la instancia de la base de datos
  Future<Db> getDatabase() async {
    if (_db != null && _db!.isConnected) {
      return _db!;
    }

    if (_isConnecting) {
      // Esperar un poco y reintentar
      await Future.delayed(const Duration(milliseconds: 100));
      return getDatabase();
    }

    await _connect();
    if (_db == null || !_db!.isConnected) {
      throw Exception(
          'No se pudo conectar a MongoDB. Verifica tu conexión y las credenciales en el archivo .env');
    }
    return _db!;
  }

  /// Conectar a MongoDB
  Future<void> _connect() async {
    if (_db != null && _db!.isConnected) return;

    _isConnecting = true;
    try {
      final mongoUri = EnvConfig.mongoUri;
      final mongoDb = EnvConfig.mongoDb;

      if (mongoUri.isEmpty || mongoDb.isEmpty) {
        throw Exception(
            'MONGO_URI y MONGO_DB deben estar configurados en el archivo .env');
      }

      // Construir URI completa con nombre de base de datos
      String fullUri = mongoUri;
      if (!mongoUri.endsWith('/')) {
        fullUri += '/';
      }
      fullUri += mongoDb;
      
      _connectionUri = fullUri;

      print('🔌 Intentando conectar a MongoDB...');
      print('📍 URI: ${_maskUri(mongoUri)}');
      print('🗄️  Base de datos: $mongoDb');

      _db = await Db.create(_connectionUri!);
      await _db!.open();

      print('✅ Conexión a MongoDB establecida correctamente');
    } catch (e) {
      print('❌ Error al conectar a MongoDB: $e');
      _db = null;
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  /// Enmascarar URI para logs (ocultar credenciales)
  String _maskUri(String uri) {
    return uri.replaceAll(
        RegExp(r'mongodb\+srv://[^:]+:[^@]+'), 'mongodb+srv://***:***');
  }

  /// Desconectar de MongoDB
  Future<void> disconnect() async {
    if (_db != null) {
      print('🔌 Cerrando conexión a MongoDB...');
      await _db!.close();
      _db = null;
      print('✅ Conexión a MongoDB cerrada');
    }
  }

  /// Obtener colección de catálogos
  Future<DbCollection> getCatalogsCollection() async {
    final db = await getDatabase();
    return db.collection('catalogs');
  }

  /// Obtener colección de usuarios
  Future<DbCollection> getUsersCollection() async {
    final db = await getDatabase();
    return db.collection('users');
  }

  // MARK: - User Operations

  /// Obtener usuario por email
  Future<User?> getUserByEmail(String email) async {
    try {
      final collection = await getUsersCollection();
      final doc = await collection.findOne({'email': email});

      if (doc == null) return null;

      return User.fromJson(doc.map((key, value) => MapEntry(key, value)));
    } catch (e) {
      print('❌ Error obteniendo usuario por email: $e');
      rethrow;
    }
  }

  /// Obtener usuario por ID
  Future<User?> getUserById(String id) async {
    try {
      final collection = await getUsersCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, buscar como string
        final doc = await collection.findOne({'_id': id});
        if (doc == null) return null;
        return User.fromJson(doc.map((key, value) => MapEntry(key, value)));
      }
      final doc = await collection.findOne(where.id(objectId));

      if (doc == null) return null;

      return User.fromJson(doc.map((key, value) => MapEntry(key, value)));
    } catch (e) {
      print('❌ Error obteniendo usuario por ID: $e');
      rethrow;
    }
  }

  /// Crear nuevo usuario
  Future<User> createUser(Map<String, dynamic> userData) async {
    try {
      final collection = await getUsersCollection();
      final result = await collection.insertOne(userData);

      if (result.isSuccess) {
        final createdUser = await getUserById(result.id.toString());
        if (createdUser == null) {
          throw Exception('Error al recuperar usuario creado');
        }
        return createdUser;
      } else {
        throw Exception('Error al crear usuario');
      }
    } catch (e) {
      print('❌ Error creando usuario: $e');
      rethrow;
    }
  }

  /// Actualizar usuario
  Future<bool> updateUser(String id, Map<String, dynamic> updates) async {
    try {
      final collection = await getUsersCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, actualizar directamente
        final result = await collection.update(
          where.eq('_id', id),
          {'\$set': updates},
        );
        return result['ok'] == 1.0;
      }
      final result = await collection.update(
        where.id(objectId),
        {'\$set': updates},
      );

      return result['ok'] == 1.0;
    } catch (e) {
      print('❌ Error actualizando usuario: $e');
      rethrow;
    }
  }

  /// Obtener todos los usuarios (para admin)
  Future<List<User>> getAllUsers() async {
    try {
      final collection = await getUsersCollection();
      final cursor = collection.find();

      final users = <User>[];
      await cursor.forEach((doc) {
        try {
          users.add(User.fromJson(doc.map((key, value) => MapEntry(key, value))));
        } catch (e) {
          print('⚠️ Error parseando usuario: $e');
        }
      });

      return users;
    } catch (e) {
      print('❌ Error obteniendo usuarios: $e');
      rethrow;
    }
  }

  // MARK: - Catalog Operations

  /// Obtener catálogos de un usuario
  Future<List<Catalog>> getCatalogs(String userId, {bool isAdmin = false}) async {
    try {
      final collection = await getCatalogsCollection();
      final selector = isAdmin ? {} : where.eq('userId', userId);
      final cursor = collection.find(selector);

      final catalogs = <Catalog>[];
      await cursor.forEach((doc) {
        try {
          catalogs.add(Catalog.fromJson(doc.map((key, value) => MapEntry(key, value))));
        } catch (e) {
          print('⚠️ Error parseando catálogo: $e');
        }
      });

      return catalogs;
    } catch (e) {
      print('❌ Error obteniendo catálogos: $e');
      rethrow;
    }
  }

  /// Obtener catálogo por ID
  Future<Catalog?> getCatalogById(String id) async {
    try {
      final collection = await getCatalogsCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, buscar como string
        final doc = await collection.findOne({'_id': id});
        if (doc == null) return null;
        return Catalog.fromJson(doc.map((key, value) => MapEntry(key, value)));
      }
      final doc = await collection.findOne(where.id(objectId));

      if (doc == null) return null;

      return Catalog.fromJson(doc.map((key, value) => MapEntry(key, value)));
    } catch (e) {
      print('❌ Error obteniendo catálogo por ID: $e');
      rethrow;
    }
  }

  /// Crear nuevo catálogo
  Future<Catalog> createCatalog(Map<String, dynamic> catalogData) async {
    try {
      final collection = await getCatalogsCollection();
      final result = await collection.insertOne(catalogData);

      if (result.isSuccess) {
        final createdCatalog = await getCatalogById(result.id.toString());
        if (createdCatalog == null) {
          throw Exception('Error al recuperar catálogo creado');
        }
        return createdCatalog;
      } else {
        throw Exception('Error al crear catálogo');
      }
    } catch (e) {
      print('❌ Error creando catálogo: $e');
      rethrow;
    }
  }

  /// Actualizar catálogo
  Future<bool> updateCatalog(String id, Map<String, dynamic> updates) async {
    try {
      final collection = await getCatalogsCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, actualizar directamente
        final result = await collection.update(
          where.eq('_id', id),
          {'\$set': updates},
        );
        return result['ok'] == 1.0;
      }
      final result = await collection.update(
        where.id(objectId),
        {'\$set': updates},
      );

      return result['ok'] == 1.0;
    } catch (e) {
      print('❌ Error actualizando catálogo: $e');
      rethrow;
    }
  }

  /// Eliminar catálogo
  Future<bool> deleteCatalog(String id) async {
    try {
      final collection = await getCatalogsCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, eliminar directamente
        final result = await collection.remove(where.eq('_id', id));
        return result['ok'] == 1.0;
      }
      final result = await collection.remove(where.id(objectId));

      return result['ok'] == 1.0;
    } catch (e) {
      print('❌ Error eliminando catálogo: $e');
      rethrow;
    }
  }
}

