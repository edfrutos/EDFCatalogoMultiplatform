import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import '../utils/env_config.dart';
import '../models/user.dart';
import '../models/catalog.dart';
import 'api_service.dart';

/// Servicio para gestionar la conexión y operaciones con MongoDB
class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  static MongoService get shared => _instance;
  MongoService._internal();

  Db? _db;
  bool _isConnecting = false;

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
        'No se pudo conectar a MongoDB. Verifica tu conexión y las credenciales en el archivo .env',
      );
    }
    return _db!;
  }

  /// Conectar a MongoDB
  Future<void> _connect() async {
    if (_db != null && _db!.isConnected) return;

    // Verificar si estamos en web
    if (kIsWeb) {
      // Si hay una API configurada, no lanzar error (se usará la API)
      if (EnvConfig.useApiBackend) {
        print('🌐 Usando backend API para conexión a MongoDB desde web');
        print('   API URL: ${EnvConfig.apiBaseUrl}');
        // No lanzar error, pero tampoco conectar directamente
        // El servicio de API se encargará de las operaciones
        return;
      }

      // Si no hay API configurada, mostrar mensaje más útil
      throw UnsupportedError(
        'MongoDB no está soportado directamente en Flutter Web.\n\n'
        'Para usar la aplicación en web, tienes dos opciones:\n\n'
        '1. Usar la aplicación en macOS, iOS o Android (recomendado)\n'
        '2. Configurar un backend API:\n'
        '   - Agrega API_BASE_URL=http://tu-api.com en tu archivo .env\n'
        '   - Configura un servidor backend que gestione MongoDB\n\n'
        'Por ahora, la aplicación funciona mejor en plataformas nativas.',
      );
    }

    _isConnecting = true;
    try {
      final mongoUri = EnvConfig.mongoUri;
      final mongoDb = EnvConfig.mongoDb;

      if (mongoUri.isEmpty || mongoDb.isEmpty) {
        throw Exception(
          'MONGO_URI y MONGO_DB deben estar configurados en el archivo .env',
        );
      }

      // Limpiar URI: quitar el nombre de BD si está incluido y asegurar formato correcto
      String cleanUri = mongoUri.trim();

      // Si la URI termina con un nombre de BD, quitarlo (todo después del último / antes de ?)
      // Formato esperado: mongodb+srv://...@cluster.net/?params o mongodb+srv://...@cluster.net/dbname?params
      if (cleanUri.contains('/') &&
          !cleanUri.contains('mongodb+srv://') &&
          cleanUri.split('/').length > 4) {
        // Si tiene más de 4 partes separadas por /, probablemente tiene nombre de BD
        final parts = cleanUri.split('/');
        // Reconstruir sin el nombre de BD (partes antes del último /)
        final baseParts = parts.sublist(0, parts.length - 1);
        cleanUri = baseParts.join('/');
        // Asegurar que tenga los parámetros de query si los tenía
        final lastPart = parts.last;
        if (lastPart.contains('?')) {
          final queryParams = lastPart.substring(lastPart.indexOf('?'));
          cleanUri += queryParams;
        }
      }

      // Si no termina en / ni ?, agregar / para luego especificar la BD
      if (!cleanUri.endsWith('/') && !cleanUri.contains('?')) {
        cleanUri += '/';
      }

      // Construir URI completa con nombre de BD
      String fullUri = cleanUri;
      if (fullUri.endsWith('/')) {
        fullUri += mongoDb;
      } else if (fullUri.contains('?')) {
        // Si tiene parámetros, insertar el nombre de BD antes del ?
        final parts = fullUri.split('?');
        fullUri = '${parts[0]}/$mongoDb?${parts[1]}';
      } else {
        fullUri += '/$mongoDb';
      }

      print('🔌 Intentando conectar a MongoDB...');
      print('📍 URI: ${_maskUri(cleanUri)}');
      print('🗄️  Base de datos: $mongoDb');

      // Crear conexión con la URI completa que incluye el nombre de la BD
      _db = await Db.create(fullUri);
      await _db!.open();

      // Verificar que estamos usando la BD correcta
      print('✅ Conexión a MongoDB establecida correctamente');
      print('✅ Base de datos confirmada: ${_db!.databaseName}');

      if (_db!.databaseName != mongoDb) {
        print(
          '⚠️ ⚠️ ⚠️ ADVERTENCIA: Base de datos esperada "$mongoDb" pero usando "${_db!.databaseName}"',
        );
        print('⚠️ Esto podría causar que no se encuentren los usuarios');
      }
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
      RegExp(r'mongodb\+srv://[^:]+:[^@]+'),
      'mongodb+srv://***:***',
    );
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

  /// Autenticar usuario por email o username con contraseña
  Future<User?> authenticateUser({
    required String emailOrUsername,
    required String password,
  }) async {
    if (kIsWeb) {
      return ApiService.instance.login(
        emailOrUsername: emailOrUsername,
        password: password,
      );
    }
    try {
      final collection = await getUsersCollection();

      print('🔍 Buscando usuario con: $emailOrUsername');

      // Diagnóstico: mostrar información de la colección
      final db = await getDatabase();
      print('📦 Base de datos actual: ${db.databaseName}');
      print('📦 Colección: users');

      final results = <Map<String, dynamic>>[];

      // Intentar buscar por Email primero
      print('🔍 Buscando por Email: $emailOrUsername');
      await collection.find({r'$or': [{'Email': emailOrUsername}, {'email': emailOrUsername}]}).forEach((doc) {
        results.add(doc.map((key, value) => MapEntry(key, value)));
      });

      // Si no se encontró por Email, buscar por Username
      if (results.isEmpty) {
        print(
          '🔍 No encontrado por Email, buscando por Username: $emailOrUsername',
        );
        await collection.find({r'$or': [{'Username': emailOrUsername}, {'username': emailOrUsername}]}).forEach((doc) {
          results.add(doc.map((key, value) => MapEntry(key, value)));
        });
      }

      // Si aún no se encontró, intentar con $or
      if (results.isEmpty) {
        print('🔍 Intentando con query \$or');
        final orQuery = <String, dynamic>{
          r'$or': [
            <String, dynamic>{'Email': emailOrUsername},
            <String, dynamic>{'Username': emailOrUsername},
          ],
        };
        await collection.find(orQuery).forEach((doc) {
          results.add(doc.map((key, value) => MapEntry(key, value)));
        });
      }

      print('📊 Resultados encontrados: ${results.length}');

      if (results.isEmpty) {
        print('❌ Usuario no encontrado con: $emailOrUsername');
        // Intentar buscar sin restricciones para ver qué usuarios existen
        print('🔍 Intentando listar primeros usuarios disponibles...');
        print('📦 Nombre de colección: users');
        try {
          // Contar total de documentos
          final totalCount = await collection.count();
          print('📊 Total de documentos en colección: $totalCount');

          if (totalCount == 0) {
            print('⚠️ La colección "users" está vacía');
            print('🔍 Verificando conexión y base de datos...');

            try {
              final db = await getDatabase();
              print('📦 Nombre de base de datos: ${db.databaseName}');

              // Intentar buscar en otras colecciones comunes con nombres alternativos
              final commonNames = ['Users', 'USER', 'User'];
              for (final name in commonNames) {
                try {
                  final altColl = db.collection(name);
                  final altCount = await altColl.count();
                  if (altCount > 0) {
                    print(
                      '🔍 ⚠️ IMPORTANTE: Encontrada colección "$name" con $altCount documentos',
                    );
                    print(
                      '   📊 Considera cambiar el nombre de colección a "$name"',
                    );

                    // Mostrar un ejemplo
                    int count = 0;
                    await for (final doc in altColl.find()) {
                      if (count >= 1) break;
                      print('   📄 Ejemplo de documento en "$name":');
                      print('      Campos: ${doc.keys.join(", ")}');
                      print(
                        '      Email: ${doc['Email'] ?? doc['email'] ?? 'N/A'}',
                      );
                      print(
                        '      Username: ${doc['Username'] ?? doc['username'] ?? 'N/A'}',
                      );
                      count++;
                    }
                  }
                } catch (e) {
                  // Colección no existe o error, continuar
                }
              }
            } catch (e) {
              print('⚠️ Error verificando colecciones: $e');
            }

            return null;
          }

          final sampleUsers = <String>[];
          int count = 0;
          await for (final doc in collection.find()) {
            if (count >= 5) break; // Limitar a 5 usuarios

            final email =
                doc['Email']?.toString() ?? doc['email']?.toString() ?? 'N/A';
            final username =
                doc['Username']?.toString() ??
                doc['username']?.toString() ??
                'N/A';
            final docId = doc['_id']?.toString() ?? 'N/A';

            // Mostrar todos los campos del documento para debugging
            print('📄 Documento ${count + 1}:');
            print('   _id: $docId');
            print('   Email: $email');
            print('   Username: $username');
            print('   Campos disponibles: ${doc.keys.join(", ")}');

            sampleUsers.add('Email: $email, Username: $username');
            count++;
          }

          if (sampleUsers.isNotEmpty) {
            print('📋 Resumen - Primeros $count usuarios:');
            for (final userInfo in sampleUsers) {
              print('   - $userInfo');
            }
          } else {
            print('⚠️ No se pudieron leer documentos de la colección');
          }
        } catch (e, stackTrace) {
          print('⚠️ Error listando usuarios: $e');
          print('📚 Stack trace: $stackTrace');
        }
        return null;
      }

      final userDoc = results.first;
      print('✅ Usuario encontrado:');
      print('   Email: ${userDoc['Email'] ?? userDoc['email']}');
      print('   Username: ${userDoc['Username'] ?? userDoc['username']}');

      final storedPassword =
          userDoc['Password']?.toString() ?? userDoc['password']?.toString();

      if (storedPassword == null) {
        print('❌ Password no encontrado en documento');
        return null;
      }

      // Verificar contraseña (múltiples métodos)
      bool passwordMatch = false;

      // Método 1: Texto plano
      if (storedPassword == password) {
        print('✅ Contraseña coincide (texto plano)');
        passwordMatch = true;
      }

      // Método 2: SHA256
      if (!passwordMatch) {
        final hash = sha256.convert(utf8.encode(password));
        final passwordHash = base64Encode(hash.bytes);
        print('🔐 Comparando hash SHA256:');
        print(
          '   Almacenado: ${storedPassword.substring(0, storedPassword.length > 30 ? 30 : storedPassword.length)}...',
        );
        print(
          '   Calculado:  ${passwordHash.substring(0, passwordHash.length > 30 ? 30 : passwordHash.length)}...',
        );
        if (storedPassword == passwordHash) {
          print('✅ Contraseña coincide (SHA256)');
          passwordMatch = true;
        } else {
          print('❌ Hashes no coinciden');
        }
      }

      // Método 3: SHA512
      if (!passwordMatch) {
        final hash = sha512.convert(utf8.encode(password));
        final passwordHash = base64Encode(hash.bytes);
        if (storedPassword == passwordHash) {
          print('✅ Contraseña coincide (SHA512)');
          passwordMatch = true;
        }
      }

      // Método 4: SHA384
      if (!passwordMatch) {
        final hash = sha384.convert(utf8.encode(password));
        final passwordHash = base64Encode(hash.bytes);
        if (storedPassword == passwordHash) {
          print('✅ Contraseña coincide (SHA384)');
          passwordMatch = true;
        }
      }

      if (!passwordMatch) {
        print('❌ Contraseña incorrecta');
        return null;
      }

      return User.fromJson(userDoc);
    } catch (e) {
      print('❌ Error autenticando usuario: $e');
      rethrow;
    }
  }

  /// Verificar si existe un usuario por email
  Future<bool> checkUserExists(String email) async {
    if (kIsWeb) return ApiService.instance.checkUserExists(email);
    try {
      final collection = await getUsersCollection();
      final doc = await collection.findOne({'Email': email});
      return doc != null;
    } catch (e) {
      print('❌ Error verificando existencia de usuario: $e');
      rethrow;
    }
  }

  /// Crear nuevo usuario
  Future<void> createUser({
    required String username,
    required String name,
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      return ApiService.instance.createUser(
        email: email,
        username: username,
        name: name,
        password: password,
      );
    }
    try {
      final collection = await getUsersCollection();

      // Hash de la contraseña con SHA256
      final hash = sha256.convert(utf8.encode(password));
      final passwordHash = base64Encode(hash.bytes);

      final userDoc = {
        '_id': ObjectId().toString(),
        'Email': email,
        'Username': username,
        'Name': name,
        'Password': passwordHash,
        'Role': 'user',
        'IsActive': true,
        'CreatedAt': DateTime.now().toIso8601String(),
      };

      await collection.insertOne(userDoc);
      print('✅ Usuario creado exitosamente');
    } catch (e) {
      print('❌ Error creando usuario: $e');
      rethrow;
    }
  }

  /// Obtener usuario por email
  Future<User?> getUserByEmail(String email) async {
    if (kIsWeb) return ApiService.instance.getUserByEmail(email);
    try {
      final collection = await getUsersCollection();
      // Intentar con 'Email' (mayúscula) primero, luego 'email' (minúscula)
      var doc = await collection.findOne({'Email': email});
      doc ??= await collection.findOne({'email': email});

      if (doc == null) return null;

      return User.fromJson(doc.map((key, value) => MapEntry(key, value)));
    } catch (e) {
      print('❌ Error obteniendo usuario por email: $e');
      rethrow;
    }
  }

  /// Obtener usuario por ID
  Future<User?> getUserById(String id) async {
    if (kIsWeb) return ApiService.instance.getUserById(id);
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

  /// Actualizar usuario
  Future<bool> updateUser(String id, Map<String, dynamic> updates) async {
    if (kIsWeb) return ApiService.instance.updateUser(id, updates);
    try {
      final collection = await getUsersCollection();
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, actualizar directamente
        final result = await collection.update(where.eq('_id', id), {
          '\$set': updates,
        });
        return result['ok'] == 1.0;
      }
      final result = await collection.update(where.id(objectId), {
        '\$set': updates,
      });

      return result['ok'] == 1.0;
    } catch (e) {
      print('❌ Error actualizando usuario: $e');
      rethrow;
    }
  }

  /// Guarda token de recuperación de contraseña
  Future<void> savePasswordResetToken(String email, String token) async {
    if (kIsWeb) return ApiService.instance.savePasswordResetToken(email, token);
    try {
      print('🔑 Guardando token de recuperación para: $email');
      final collection = await getUsersCollection();

      // Expira en 1 hora
      final expiresAt = DateTime.now().add(const Duration(hours: 1));

      final result = await collection.update(where.eq('Email', email), {
        '\$set': {
          'ResetToken': token,
          'ResetTokenExpires': expiresAt.toIso8601String(),
        },
      });

      if (result['nModified'] == 0) {
        throw Exception('Usuario no encontrado');
      }

      print('✅ Token guardado correctamente');
    } catch (e) {
      print('❌ Error guardando token: $e');
      rethrow;
    }
  }

  /// Verifica el token de recuperación de contraseña
  Future<bool> verifyPasswordResetToken(String email, String token) async {
    if (kIsWeb) return ApiService.instance.verifyPasswordResetToken(email, token);
    try {
      print('🔍 Verificando token de recuperación para: $email');
      final collection = await getUsersCollection();

      final doc = await collection.findOne({
        'Email': email,
        'ResetToken': token,
      });

      if (doc == null) {
        print('❌ Token no encontrado o no coincide');
        return false;
      }

      // Verificar que no haya expirado
      final expiresAtStr = doc['ResetTokenExpires'];
      if (expiresAtStr == null) {
        print('❌ Token sin fecha de expiración');
        return false;
      }

      final expiresAt = DateTime.parse(expiresAtStr);
      if (expiresAt.isBefore(DateTime.now())) {
        print('❌ Token expirado');
        return false;
      }

      print('✅ Token válido');
      return true;
    } catch (e) {
      print('❌ Error verificando token: $e');
      return false;
    }
  }

  /// Actualiza la contraseña de un usuario
  Future<void> updatePassword(String email, String newPassword) async {
    if (kIsWeb) return ApiService.instance.updatePassword(email, newPassword);
    try {
      print('🔑 Actualizando contraseña para: $email');
      final collection = await getUsersCollection();

      // Hash de la nueva contraseña con SHA256
      final hash = sha256.convert(utf8.encode(newPassword));
      final passwordHash = base64Encode(hash.bytes);

      final result = await collection.update(where.eq('Email', email), {
        '\$set': {'Password': passwordHash},
      });

      if (result['nModified'] == 0) {
        throw Exception('Usuario no encontrado');
      }

      print('✅ Contraseña actualizada correctamente');
    } catch (e) {
      print('❌ Error actualizando contraseña: $e');
      rethrow;
    }
  }

  /// Limpia el token de recuperación de contraseña
  Future<void> clearPasswordResetToken(String email) async {
    if (kIsWeb) return ApiService.instance.clearPasswordResetToken(email);
    try {
      print('🧽 Limpiando token de recuperación para: $email');
      final collection = await getUsersCollection();

      await collection.update(where.eq('Email', email), {
        '\$unset': {'ResetToken': '', 'ResetTokenExpires': ''},
      });

      print('✅ Token limpiado correctamente');
    } catch (e) {
      print('❌ Error limpiando token: $e');
      // No lanzar error, es una operación de limpieza
    }
  }

  /// Obtener todos los usuarios (para admin)
  Future<List<User>> getAllUsers() async {
    if (kIsWeb) return ApiService.instance.getAllUsers();
    try {
      final collection = await getUsersCollection();
      final cursor = collection.find();

      final users = <User>[];
      await cursor.forEach((doc) {
        try {
          users.add(
            User.fromJson(doc.map((key, value) => MapEntry(key, value))),
          );
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

  /// Eliminar usuario físicamente de la base de datos
  Future<bool> deleteUser(String id) async {
    if (kIsWeb) return ApiService.instance.deleteUser(id);
    try {
      print('🗑️ Intentando eliminar usuario con ID: $id');
      final collection = await getUsersCollection();

      // Verificar que el usuario existe antes de eliminarlo
      var userDoc = await collection.findOne({'_id': id});
      if (userDoc == null) {
        // Intentar con ObjectId
        try {
          final objectId = ObjectId.fromHexString(id);
          userDoc = await collection.findOne(where.id(objectId));
        } catch (_) {
          // Ignorar error de parsing
        }
      }

      if (userDoc == null) {
        print('❌ Usuario no encontrado con ID: $id');
        return false;
      }

      print('✅ Usuario encontrado, procediendo a eliminar...');

      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, eliminar directamente
        print('📝 Eliminando usuario con ID como string: $id');
        final result = await collection.remove(where.eq('_id', id));
        print('📊 Resultado de eliminación: $result');
        final success = result['ok'] == 1.0 || result['n'] > 0;
        if (success) {
          print('✅ Usuario eliminado exitosamente');
        } else {
          print('❌ Error: No se pudo eliminar el usuario (result: $result)');
        }
        return success;
      }

      print('📝 Eliminando usuario con ObjectId: $objectId');
      final result = await collection.remove(where.id(objectId));
      print('📊 Resultado de eliminación: $result');
      final success = result['ok'] == 1.0 || result['n'] > 0;
      if (success) {
        print('✅ Usuario eliminado exitosamente');
      } else {
        print('❌ Error: No se pudo eliminar el usuario (result: $result)');
      }
      return success;
    } catch (e, stackTrace) {
      print('❌ Error eliminando usuario: $e');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Estadísticas de usuarios para el panel de administración.
  /// Devuelve: total, activos, inactivos, admins, usuarios normales.
  Future<Map<String, int>> getUserStats() async {
    if (kIsWeb) return ApiService.instance.getUserStats();
    try {
      final collection = await getUsersCollection();
      final all = await collection.find().toList();

      int total = all.length;
      int active = 0;
      int inactive = 0;
      int admins = 0;
      int regularUsers = 0;

      for (final doc in all) {
        final isActive = doc['IsActive'] as bool? ?? doc['isActive'] as bool? ?? true;
        final role = (doc['Role'] as String? ?? doc['role'] as String? ?? 'user').toLowerCase();

        if (isActive) {
          active++;
        } else {
          inactive++;
        }

        if (role == 'admin') {
          admins++;
        } else {
          regularUsers++;
        }
      }

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'admins': admins,
        'users': regularUsers,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas de usuarios: $e');
      rethrow;
    }
  }

  // MARK: - Catalog Operations

  /// Obtener catálogos de un usuario
  Future<List<Catalog>> getCatalogs(
    String userId, {
    bool isAdmin = false,
    String? userEmail, // Email del usuario para buscar en Owner/CreatedBy
  }) async {
    if (kIsWeb) {
      return ApiService.instance.getCatalogs(
        userId,
        isAdmin: isAdmin,
        userEmail: userEmail,
      );
    }
    try {
      final collection = await getCatalogsCollection();
      // Usar Map directamente en lugar de SelectorBuilder para evitar errores
      // MongoDB puede usar 'Owner', 'CreatedBy' o 'userId' para el propietario
      // Owner/CreatedBy normalmente contienen el email del usuario
      final selector = isAdmin
          ? <String, dynamic>{}
          : <String, dynamic>{
              r'$or': [
                {'Owner': userId},
                {'CreatedBy': userId},
                {'userId': userId},
                // También buscar por email si está disponible
                if (userEmail != null) {'Owner': userEmail},
                if (userEmail != null) {'CreatedBy': userEmail},
              ],
            };
      final cursor = collection.find(selector);
      print(
        '🔍 Consulta de catálogos: isAdmin=$isAdmin, userId=$userId, selector=$selector',
      );

      final catalogs = <Catalog>[];
      int totalFound = 0;
      int parsedSuccessfully = 0;
      int parseErrors = 0;

      await cursor.forEach((doc) {
        totalFound++;
        try {
          final catalog = Catalog.fromJson(
            doc.map((key, value) => MapEntry(key, value)),
          );
          catalogs.add(catalog);
          parsedSuccessfully++;
          print('✅ Catálogo parseado: ${catalog.name} (ID: ${catalog.id})');
        } catch (e, stackTrace) {
          parseErrors++;
          print('⚠️ Error parseando catálogo: $e');
          print('   Stack trace: $stackTrace');
          print(
            '   Documento: ${doc.toString().substring(0, doc.toString().length > 200 ? 200 : doc.toString().length)}...',
          );
        }
      });

      print('📊 Resumen de catálogos:');
      print('   - Total encontrados en MongoDB: $totalFound');
      print('   - Parseados correctamente: $parsedSuccessfully');
      print('   - Errores de parsing: $parseErrors');
      print('   - Catálogos retornados: ${catalogs.length}');

      return catalogs;
    } catch (e) {
      print('❌ Error obteniendo catálogos: $e');
      rethrow;
    }
  }

  /// Obtener catálogo por ID
  Future<Catalog?> getCatalogById(String id) async {
    if (kIsWeb) return ApiService.instance.getCatalogById(id);
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

  /// Crear nuevo catálogo (sobrecarga con parámetros nombrados)
  Future<Catalog> createCatalog({
    required String name,
    required String description,
    required String userId,
    required List<String> columns,
  }) async {
    if (kIsWeb) {
      return ApiService.instance.createCatalog(
        name: name,
        description: description,
        userId: userId,
        columns: columns,
      );
    }
    try {
      final collection = await getCatalogsCollection();
      final now = DateTime.now();

      final catalogData = {
        'Name': name,
        'Description': description,
        'Category': '',
        'Fecha': now.toIso8601String(),
        'DocumentoUrl': '',
        'MultimediaUrl': '',
        'ImagenUrl': '',
        'Headers': columns,
        'Rows': <Map<String, dynamic>>[],
        'LegacyRows': <Map<String, dynamic>>[],
        'userId': userId, // Añadir userId en minúscula también
        'CreatedBy': userId,
        'Owner': userId,
        'CreatedAt': now.toIso8601String(),
        'UpdatedAt': now.toIso8601String(),
        'Miniatura': null,
      };

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

  /// Crear nuevo catálogo (sobrecarga con Map)
  Future<Catalog> createCatalogFromMap(Map<String, dynamic> catalogData) async {
    if (kIsWeb) return ApiService.instance.createCatalogFromMap(catalogData);
    try {
      final collection = await getCatalogsCollection();

      // Asegurar que el documento tenga un _id si no lo tiene
      if (!catalogData.containsKey('_id')) {
        catalogData['_id'] = ObjectId();
      }

      final result = await collection.insertOne(catalogData);

      if (result.isSuccess) {
        // Construir el Catalog directamente desde los datos insertados
        // en lugar de intentar recuperar el catálogo de la base de datos
        // (evita problemas de timing y formato de ID)

        // El ID ya está en catalogData (lo añadimos antes si no existía)
        // MongoDB puede haberlo modificado, así que usamos el ID del resultado
        final insertedId = result.id;

        // Asegurar que el ID esté en el formato correcto
        final catalogWithId = Map<String, dynamic>.from(catalogData);
        if (insertedId is ObjectId) {
          // Mantener el ObjectId para que Catalog.fromJson lo maneje correctamente
          catalogWithId['_id'] = insertedId;
        } else {
          // Si no es ObjectId, convertir a string
          catalogWithId['_id'] = insertedId.toString();
        }

        try {
          return Catalog.fromJson(catalogWithId);
        } catch (e) {
          // Si falla al parsear, intentar recuperar de la base de datos como fallback
          print(
            '⚠️ Error parseando catálogo desde datos, intentando recuperar de BD: $e',
          );
          final idString = insertedId is ObjectId
              ? insertedId.oid
              : insertedId.toString();
          final createdCatalog = await getCatalogById(idString);
          if (createdCatalog == null) {
            throw Exception(
              'Error al crear y recuperar catálogo: no se pudo parsear ni recuperar',
            );
          }
          return createdCatalog;
        }
      } else {
        throw Exception('Error al crear catálogo: inserción falló');
      }
    } catch (e) {
      print('❌ Error creando catálogo: $e');
      rethrow;
    }
  }

  /// Actualizar catálogo (sobrecarga que acepta objeto Catalog)
  Future<bool> updateCatalogFromObject(Catalog catalog) async {
    if (kIsWeb) return ApiService.instance.updateCatalogFromObject(catalog);
    try {
      // Convertir filas a JSON y verificar que FileTitles se incluye
      final rowsJson = catalog.rows.map((row) {
        final rowJson = row.toJson();
        // Verificar que FileTitles está presente en cada fila
        if (rowJson['Files'] != null && rowJson['Files'] is Map) {
          final filesMap = rowJson['Files'] as Map;
          if (filesMap.containsKey('FileTitles')) {
            final fileTitles = filesMap['FileTitles'];
            if (fileTitles is Map) {
              print(
                '💾 updateCatalogFromObject - Fila ${row.id} tiene FileTitles con ${fileTitles.length} entradas',
              );
            } else {
              print(
                '⚠️ updateCatalogFromObject - Fila ${row.id} tiene FileTitles pero NO es Map: ${fileTitles.runtimeType}',
              );
            }
          } else {
            print(
              '⚠️ updateCatalogFromObject - Fila ${row.id} NO tiene FileTitles en Files',
            );
          }
        }
        return rowJson;
      }).toList();

      final updates = <String, dynamic>{
        'Name': catalog.name,
        'Description': catalog.description,
        'Headers': catalog.columns,
        'Rows': rowsJson,
        'UpdatedAt': catalog.updatedAt.toIso8601String(),
      };

      // Incluir Miniatura (thumbnailUrl)
      if (catalog.thumbnailUrl != null && catalog.thumbnailUrl!.isNotEmpty) {
        updates['Miniatura'] = catalog.thumbnailUrl;
      } else {
        // Si es null o vacío, eliminar el campo usando $unset
        updates['Miniatura'] = null;
      }

      // Debug: verificar que thumbnailUrl se está incluyendo
      print('💾 Actualizando catálogo - Miniatura: ${catalog.thumbnailUrl}');
      print(
        '💾 Actualizando catálogo - Total de filas a actualizar: ${rowsJson.length}',
      );

      return await updateCatalog(catalog.id, updates);
    } catch (e) {
      print('❌ Error actualizando catálogo: $e');
      rethrow;
    }
  }

  /// Actualizar catálogo
  Future<bool> updateCatalog(String id, Map<String, dynamic> updates) async {
    if (kIsWeb) return ApiService.instance.updateCatalog(id, updates);
    try {
      final collection = await getCatalogsCollection();

      // Separar campos a establecer ($set) y campos a eliminar ($unset)
      final setFields = <String, dynamic>{};
      final unsetFields = <String, dynamic>{};

      for (final entry in updates.entries) {
        if (entry.value == null) {
          unsetFields[entry.key] = '';
        } else {
          setFields[entry.key] = entry.value;
        }
      }

      final updateDoc = <String, dynamic>{};
      if (setFields.isNotEmpty) {
        updateDoc['\$set'] = setFields;
        // Debug: verificar que Rows se está incluyendo en $set
        if (setFields.containsKey('Rows') && setFields['Rows'] is List) {
          final rowsList = setFields['Rows'] as List;
          print(
            '💾 updateCatalog - Actualizando ${rowsList.length} filas en MongoDB',
          );
          for (int i = 0; i < rowsList.length; i++) {
            final row = rowsList[i];
            if (row is Map && row.containsKey('Files')) {
              final files = row['Files'];
              if (files is Map) {
                if (files.containsKey('FileTitles')) {
                  final fileTitles = files['FileTitles'];
                  if (fileTitles is Map) {
                    print(
                      '   Fila $i: FileTitles con ${fileTitles.length} entradas',
                    );
                  } else {
                    print(
                      '   ⚠️ Fila $i: FileTitles NO es Map: ${fileTitles.runtimeType}',
                    );
                  }
                } else {
                  print('   ⚠️ Fila $i: NO tiene FileTitles');
                }
              }
            }
          }
        }
      }
      if (unsetFields.isNotEmpty) {
        updateDoc['\$unset'] = unsetFields;
      }

      if (updateDoc.isEmpty) {
        print('⚠️ No hay campos para actualizar');
        return true;
      }

      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, actualizar directamente con string
        print('💾 updateCatalog - Actualizando con _id como string: $id');
        final result = await collection.update(where.eq('_id', id), updateDoc);
        final success = (result['ok'] as num?)?.toInt() == 1;
        print(
          '💾 updateCatalog - Resultado: ${success ? "✅ Éxito" : "❌ Falló"} | raw=$result',
        );
        return success;
      }

      // Intentar primero con ObjectId
      print('💾 updateCatalog - Actualizando con ObjectId: ${objectId.oid}');
      var result = await collection.update(where.id(objectId), updateDoc);
      var nModified = (result['nModified'] as num?)?.toInt() ?? -1;
      var okVal = (result['ok'] as num?)?.toInt() ?? 0;
      print('💾 updateCatalog - ObjectId → ok=$okVal nModified=$nModified');

      // Si no modificó nada o falló, el _id puede estar guardado como string
      if (nModified == 0 || okVal != 1) {
        print('💾 updateCatalog - Reintentando con _id string: $id');
        result = await collection.update(where.eq('_id', id), updateDoc);
        nModified = (result['nModified'] as num?)?.toInt() ?? 0;
        okVal = (result['ok'] as num?)?.toInt() ?? 0;
        print('💾 updateCatalog - String → ok=$okVal nModified=$nModified');
      }

      final success = okVal == 1;
      print(
        '💾 updateCatalog - Resultado final: ${success ? "✅ Éxito" : "❌ Falló"} | nModified=$nModified',
      );
      return success;
    } catch (e) {
      print('❌ Error actualizando catálogo: $e');
      rethrow;
    }
  }

  /// Eliminar catálogo
  Future<bool> deleteCatalog(String id) async {
    if (kIsWeb) return ApiService.instance.deleteCatalog(id);
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
