import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/catalog.dart';
import '../services/mongo_service.dart';
import '../services/local_storage_service.dart';

/// Servicio para sincronización de datos (online/offline)
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  static SyncService get shared => _instance;
  SyncService._internal();

  final MongoService _mongoService = MongoService.shared;
  final LocalStorageService _localStorage = LocalStorageService.shared;
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Verifica si hay conexión a internet
  Future<bool> hasConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// Escucha cambios en la conectividad
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Sincroniza datos pendientes cuando se recupera la conexión
  Future<void> syncPendingOperations() async {
    if (_isSyncing) {
      print('⚠️ Sincronización ya en curso');
      return;
    }

    if (!await hasConnection()) {
      print('⚠️ Sin conexión, no se puede sincronizar');
      return;
    }

    _isSyncing = true;
    print('🔄 Iniciando sincronización...');

    try {
      final queue = await _localStorage.getSyncQueue();
      print('📋 Operaciones pendientes: ${queue.length}');

      for (final operation in queue) {
        try {
          await _processSyncOperation(operation);
        } catch (e) {
          print('❌ Error procesando operación: ${operation['operation']} - $e');
          // Continuar con las demás operaciones
        }
      }

      // Limpiar cola después de sincronizar exitosamente
      await _localStorage.clearSyncQueue();

      _lastSyncTime = DateTime.now();
      print('✅ Sincronización completada');
    } catch (e) {
      print('❌ Error en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Procesa una operación individual de la cola
  Future<void> _processSyncOperation(Map<String, dynamic> operation) async {
    final opType = operation['operation'] as String;
    final data = operation['data'] as Map<String, dynamic>;

    switch (opType) {
      case 'create':
        if (data.containsKey('catalog')) {
          // Crear catálogo
          final catalog = Catalog.fromJson(data['catalog']);
          await _mongoService.createCatalog(
            name: catalog.name,
            description: catalog.description,
            userId: catalog.userId,
            columns: catalog.columns,
          );
        }
        break;
      case 'update':
        if (data.containsKey('catalog')) {
          // Actualizar catálogo
          final catalog = Catalog.fromJson(data['catalog']);
          await _mongoService.updateCatalogFromObject(catalog);
        }
        break;
      case 'delete':
        if (data.containsKey('catalogId')) {
          // Eliminar catálogo
          await _mongoService.deleteCatalog(data['catalogId']);
        }
        break;
      default:
        print('⚠️ Operación desconocida: $opType');
    }
  }

  /// Sincroniza catálogos desde el servidor y guarda localmente
  Future<void> syncCatalogsFromServer({
    required String userId,
    required bool isAdmin,
    String? userEmail,
  }) async {
    if (!await hasConnection()) {
      print('⚠️ Sin conexión, usando datos locales');
      return;
    }

    try {
      print('🔄 Sincronizando catálogos desde servidor...');
      final catalogs = await _mongoService.getCatalogs(
        userId,
        isAdmin: isAdmin,
        userEmail: userEmail,
      );

      // Guardar localmente
      await _localStorage.saveCatalogsLocally(catalogs);
      _lastSyncTime = DateTime.now();

      print('✅ ${catalogs.length} catálogos sincronizados');
    } catch (e) {
      print('❌ Error sincronizando desde servidor: $e');
    }
  }

  /// Obtiene catálogos (desde servidor si hay conexión, sino desde local)
  /// [forceRefresh] - Si es true, siempre carga desde MongoDB ignorando caché local
  Future<List<Catalog>> getCatalogs({
    required String userId,
    required bool isAdmin,
    String? userEmail,
    bool forceRefresh = false,
  }) async {
    if (await hasConnection()) {
      try {
        // Siempre cargar desde servidor si hay conexión (para obtener datos actualizados)
        // Solo usar caché local como fallback si falla la conexión
        final catalogs = await _mongoService.getCatalogs(
          userId,
          isAdmin: isAdmin,
          userEmail: userEmail,
        );
        // Guardar localmente para uso offline
        await _localStorage.saveCatalogsLocally(catalogs);
        return catalogs;
      } catch (e) {
        print('⚠️ Error obteniendo desde servidor, usando datos locales: $e');
        // Fallback a datos locales solo si falla la conexión
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        // Filtrar por userId si no es admin
        if (!isAdmin) {
          return localCatalogs.where((c) => c.userId == userId).toList();
        }
        return localCatalogs;
      }
    } else {
      // Sin conexión, usar datos locales
      print('📴 Sin conexión, usando datos locales');
      final localCatalogs = await _localStorage.loadCatalogsLocally();
      // Filtrar por userId si no es admin
      if (!isAdmin) {
        return localCatalogs.where((c) => c.userId == userId).toList();
      }
      return localCatalogs;
    }
  }

  /// Crea un catálogo (intenta en servidor, guarda en cola si falla)
  Future<bool> createCatalog({
    required String name,
    required String description,
    required String userId,
    required List<String> columns,
  }) async {
    try {
      if (await hasConnection()) {
        // Crear en servidor
        final catalog = await _mongoService.createCatalog(
          name: name,
          description: description,
          userId: userId,
          columns: columns,
        );
        // Guardar localmente también
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        localCatalogs.add(catalog);
        await _localStorage.saveCatalogsLocally(localCatalogs);
        return true;
      } else {
        // Sin conexión, crear localmente y agregar a cola
        print('📴 Sin conexión, guardando localmente y agregando a cola');
        final tempCatalog = Catalog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          description: description,
          userId: userId,
          columns: columns,
          rows: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final localCatalogs = await _localStorage.loadCatalogsLocally();
        localCatalogs.add(tempCatalog);
        await _localStorage.saveCatalogsLocally(localCatalogs);

        // Agregar a cola de sincronización
        await _localStorage.addToSyncQueue('create', {
          'catalog': tempCatalog.toJson(),
        });

        return true;
      }
    } catch (e) {
      print('❌ Error creando catálogo: $e');
      return false;
    }
  }

  /// Actualiza un catálogo (intenta en servidor, guarda en cola si falla)
  Future<bool> updateCatalog(Catalog catalog) async {
    try {
      if (await hasConnection()) {
        // Actualizar en servidor
        await _mongoService.updateCatalogFromObject(catalog);

        // Actualizar localmente
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        final index = localCatalogs.indexWhere((c) => c.id == catalog.id);
        if (index != -1) {
          localCatalogs[index] = catalog;
          await _localStorage.saveCatalogsLocally(localCatalogs);
        }
        return true;
      } else {
        // Sin conexión, actualizar localmente y agregar a cola
        print('📴 Sin conexión, actualizando localmente y agregando a cola');
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        final index = localCatalogs.indexWhere((c) => c.id == catalog.id);
        if (index != -1) {
          localCatalogs[index] = catalog;
          await _localStorage.saveCatalogsLocally(localCatalogs);
        }

        // Agregar a cola de sincronización
        await _localStorage.addToSyncQueue('update', {
          'catalog': catalog.toJson(),
        });

        return true;
      }
    } catch (e) {
      print('❌ Error actualizando catálogo: $e');
      return false;
    }
  }

  /// Elimina un catálogo (intenta en servidor, guarda en cola si falla)
  Future<bool> deleteCatalog(String catalogId) async {
    try {
      if (await hasConnection()) {
        // Eliminar en servidor
        await _mongoService.deleteCatalog(catalogId);

        // Eliminar localmente
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        localCatalogs.removeWhere((c) => c.id == catalogId);
        await _localStorage.saveCatalogsLocally(localCatalogs);
        return true;
      } else {
        // Sin conexión, eliminar localmente y agregar a cola
        print('📴 Sin conexión, eliminando localmente y agregando a cola');
        final localCatalogs = await _localStorage.loadCatalogsLocally();
        localCatalogs.removeWhere((c) => c.id == catalogId);
        await _localStorage.saveCatalogsLocally(localCatalogs);

        // Agregar a cola de sincronización
        await _localStorage.addToSyncQueue('delete', {'catalogId': catalogId});

        return true;
      }
    } catch (e) {
      print('❌ Error eliminando catálogo: $e');
      return false;
    }
  }
}
