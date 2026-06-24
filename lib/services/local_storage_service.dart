import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import '../models/catalog.dart';
import '../models/user.dart';

/// Servicio para almacenamiento local (modo offline)
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  static LocalStorageService get shared => _instance;
  LocalStorageService._internal();

  File? _catalogsFile;
  File? _usersFile;
  File? _syncQueueFile;

  Future<void> _ensureInitialized() async {
    if (_catalogsFile != null) return;
    // En web no hay sistema de ficheros nativo — los datos vienen del servidor
    if (kIsWeb) return;

    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/edfcatalogo');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    _catalogsFile = File('${appDir.path}/catalogs.json');
    _usersFile = File('${appDir.path}/users.json');
    _syncQueueFile = File('${appDir.path}/sync_queue.json');
  }

  /// Guarda catálogos localmente
  Future<void> saveCatalogsLocally(List<Catalog> catalogs) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      final jsonList = catalogs.map((c) => c.toJson()).toList();
      await _catalogsFile!.writeAsString(jsonEncode(jsonList));
      print('✅ Catálogos guardados localmente: ${catalogs.length}');
    } catch (e) {
      print('❌ Error guardando catálogos localmente: $e');
      rethrow;
    }
  }

  /// Carga catálogos desde almacenamiento local
  Future<List<Catalog>> loadCatalogsLocally() async {
    if (kIsWeb) return [];
    await _ensureInitialized();
    try {
      if (!await _catalogsFile!.exists()) {
        return [];
      }

      final jsonString = await _catalogsFile!.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Catalog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Error cargando catálogos localmente: $e');
      return [];
    }
  }

  /// Guarda usuario localmente
  Future<void> saveUserLocally(User user) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      await _usersFile!.writeAsString(jsonEncode(user.toJson()));
      print('✅ Usuario guardado localmente');
    } catch (e) {
      print('❌ Error guardando usuario localmente: $e');
    }
  }

  /// Carga usuario desde almacenamiento local
  Future<User?> loadUserLocally() async {
    if (kIsWeb) return null;
    await _ensureInitialized();
    try {
      if (!await _usersFile!.exists()) {
        return null;
      }

      final jsonString = await _usersFile!.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (e) {
      print('❌ Error cargando usuario localmente: $e');
      return null;
    }
  }

  /// Agrega una operación a la cola de sincronización
  Future<void> addToSyncQueue(String operation, Map<String, dynamic> data) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      List<Map<String, dynamic>> queue = [];
      
      if (await _syncQueueFile!.exists()) {
        final jsonString = await _syncQueueFile!.readAsString();
        queue = List<Map<String, dynamic>>.from(jsonDecode(jsonString));
      }

      queue.add({
        'operation': operation, // 'create', 'update', 'delete'
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _syncQueueFile!.writeAsString(jsonEncode(queue));
      print('✅ Operación agregada a cola de sincronización: $operation');
    } catch (e) {
      print('❌ Error agregando a cola de sincronización: $e');
    }
  }

  /// Obtiene la cola de sincronización
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    if (kIsWeb) return [];
    await _ensureInitialized();
    try {
      if (!await _syncQueueFile!.exists()) {
        return [];
      }

      final jsonString = await _syncQueueFile!.readAsString();
      return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    } catch (e) {
      print('❌ Error obteniendo cola de sincronización: $e');
      return [];
    }
  }

  /// Limpia la cola de sincronización
  Future<void> clearSyncQueue() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      if (await _syncQueueFile!.exists()) {
        await _syncQueueFile!.delete();
      }
      print('✅ Cola de sincronización limpiada');
    } catch (e) {
      print('❌ Error limpiando cola de sincronización: $e');
    }
  }

  /// Limpia todos los datos locales
  Future<void> clearAllLocalData() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      if (await _catalogsFile!.exists()) {
        await _catalogsFile!.delete();
      }
      if (await _usersFile!.exists()) {
        await _usersFile!.delete();
      }
      if (await _syncQueueFile!.exists()) {
        await _syncQueueFile!.delete();
      }
      print('✅ Todos los datos locales eliminados');
    } catch (e) {
      print('❌ Error limpiando datos locales: $e');
    }
  }

  /// Verifica si hay operaciones pendientes de sincronizar
  Future<bool> hasPendingSync() async {
    final queue = await getSyncQueue();
    return queue.isNotEmpty;
  }
}

