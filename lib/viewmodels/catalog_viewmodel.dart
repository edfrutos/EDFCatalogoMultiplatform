import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/catalog.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';

class CatalogViewModel extends ChangeNotifier {
  final SyncService _syncService = SyncService.shared;
  final LocalStorageService _localStorage = LocalStorageService.shared;
  final Connectivity _connectivity = Connectivity();

  List<Catalog> _catalogs = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<Catalog> get catalogs => _catalogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;

  CatalogViewModel() {
    // Iniciar listener de conectividad de forma asíncrona (puede fallar en Docker sin DBus)
    // No bloqueamos la construcción del ViewModel si falla
    _initConnectivityListenerAsync();
  }

  /// Inicializa el listener de cambios de conectividad de forma asíncrona
  /// Esto evita que los errores de DBus bloqueen la construcción del ViewModel
  void _initConnectivityListenerAsync() {
    // Ejecutar de forma asíncrona para no bloquear la construcción
    Future.microtask(() async {
      try {
        _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          (List<ConnectivityResult> results) async {
            try {
              final wasOffline = _isOffline;
              // En la nueva API, se devuelve una lista. Si está vacía o contiene 'none', está offline
              _isOffline =
                  results.isEmpty || results.contains(ConnectivityResult.none);

              // Si cambió de offline a online, sincronizar automáticamente
              if (wasOffline && !_isOffline) {
                print('✅ Conexión recuperada, sincronizando...');
                if (await _localStorage.hasPendingSync()) {
                  await syncPendingData();
                }
              }

              notifyListeners();
            } catch (e) {
              // Ignorar errores en el listener para no interrumpir la app
              print('⚠️ Error en listener de conectividad: $e');
            }
          },
          onError: (error) {
            // Manejar errores del stream (DBus no disponible en Docker)
            print(
              '⚠️ Error en stream de conectividad (normal en Docker): $error',
            );
            print('   La aplicación continuará funcionando sin el listener');
            // No hacer nada, la app puede funcionar sin el listener
          },
          cancelOnError: false, // No cancelar la suscripción si hay error
        );
        print('✅ Listener de conectividad inicializado');
      } catch (e, stackTrace) {
        // En Docker/Linux, DBus puede no estar disponible
        // Esto no es crítico, la app puede funcionar sin el listener
        print(
          '⚠️ No se pudo inicializar el listener de conectividad (normal en Docker): $e',
        );
        print('   La aplicación continuará funcionando normalmente');
        _isOffline = false; // Asumir conexión por defecto
        // No re-lanzar el error, simplemente continuar sin el listener
      }
    });
  }

  /// Verifica y actualiza el estado de conectividad manualmente
  Future<void> checkConnectivity() async {
    try {
      final hasConnection = await _syncService.hasConnection();
      final wasOffline = _isOffline;
      _isOffline = !hasConnection;

      // Si cambió de offline a online, sincronizar
      if (wasOffline && !_isOffline && await _localStorage.hasPendingSync()) {
        await syncPendingData();
      }

      notifyListeners();
    } catch (e) {
      // Si falla la verificación (DBus no disponible), asumir conexión
      print('⚠️ Error verificando conectividad, asumiendo conexión: $e');
      _isOffline = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> loadCatalogs({
    required String userId,
    required bool isAdmin,
    String? userEmail,
  }) async {
    print('🚀 loadCatalogs iniciado para usuario: $userId, admin: $isAdmin');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Verificar conexión (puede fallar en Docker, pero intentaremos de todas formas)
      bool hasConnection = false;
      print('🔍 Verificando conexión...');
      try {
        hasConnection = await _syncService.hasConnection();
        print('✅ Verificación de conexión completada: $hasConnection');
      } catch (e, stackTrace) {
        // Si la verificación de conectividad falla (común en Docker),
        // asumimos que hay conexión y lo intentamos de todas formas
        print(
          '⚠️ Verificación de conectividad falló, intentando de todas formas: $e',
        );
        print('   Stack trace: $stackTrace');
        hasConnection = true;
      }
      _isOffline = !hasConnection;
      print(
        '📡 Estado de conexión: hasConnection=$hasConnection, isOffline=$_isOffline',
      );

      if (hasConnection) {
        try {
          // Intentar sincronizar desde servidor
          await _syncService.syncCatalogsFromServer(
            userId: userId,
            isAdmin: isAdmin,
            userEmail: userEmail,
          );
        } catch (e) {
          print('⚠️ Error sincronizando desde servidor, continuando: $e');
          // Continuar aunque falle la sincronización
        }
      }

      // Obtener catálogos (desde servidor si hay conexión, sino desde local)
      print('📋 Obteniendo catálogos...');
      _catalogs = await _syncService.getCatalogs(
        userId: userId,
        isAdmin: isAdmin,
        userEmail: userEmail,
      );
      print('✅ Catálogos obtenidos: ${_catalogs.length}');

      _error = null;

      // Si hay operaciones pendientes y hay conexión, sincronizar
      if (hasConnection && await _localStorage.hasPendingSync()) {
        _syncService.syncPendingOperations();
      }
    } catch (e, stackTrace) {
      print('❌ Error en loadCatalogs: $e');
      print('   Stack trace: $stackTrace');
      _error = 'No se pudieron cargar los catálogos: $e';
      // Fallback a datos locales
      print('🔄 Intentando cargar catálogos desde almacenamiento local...');
      try {
        _catalogs = await _localStorage.loadCatalogsLocally();
        _isOffline = true;
        print(
          '✅ Catálogos cargados desde almacenamiento local: ${_catalogs.length}',
        );
      } catch (localError) {
        // Si también falla la carga local, dejar error
        print('❌ Error cargando desde almacenamiento local: $localError');
      }
    } finally {
      _isLoading = false;
      print(
        '🔄 Actualizando UI: isLoading=$_isLoading, catálogos=${_catalogs.length}, error=$_error',
      );
      notifyListeners();
      print('✅ UI actualizada');
    }
  }

  Future<bool> createCatalog({
    required String name,
    required String description,
    required String userId,
    required List<String> columns,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Usar SyncService que maneja online/offline
      final success = await _syncService.createCatalog(
        name: name,
        description: description,
        userId: userId,
        columns: columns,
      );

      if (success) {
        // Recargar catálogos para obtener el actualizado
        await loadCatalogs(userId: userId, isAdmin: false);
      }

      _error = null;
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'No se pudo crear el catálogo: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCatalog({
    required Catalog catalog,
    required String name,
    required String description,
    required List<String> columns,
    String? thumbnailUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCatalog = Catalog(
        id: catalog.id,
        name: name,
        description: description,
        userId: catalog.userId,
        columns: columns,
        rows: catalog.rows,
        legacyRows: catalog.legacyRows,
        thumbnailUrl: thumbnailUrl,
        createdAt: catalog.createdAt,
        updatedAt: DateTime.now(),
      );

      // Usar SyncService que maneja online/offline
      final success = await _syncService.updateCatalog(updatedCatalog);

      if (success) {
        final index = _catalogs.indexWhere((c) => c.id == catalog.id);
        if (index != -1) {
          _catalogs[index] = updatedCatalog;
        }
      }

      _error = null;
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'No se pudo actualizar el catálogo: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCatalog({required String catalogId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Usar SyncService que maneja online/offline
      final success = await _syncService.deleteCatalog(catalogId);

      if (success) {
        _catalogs.removeWhere((c) => c.id == catalogId);
      }

      _error = null;
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'No se pudo eliminar el catálogo: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sincroniza manualmente los datos pendientes
  Future<void> syncPendingData({
    String? userId,
    bool? isAdmin,
    String? userEmail,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Verificar conexión antes de sincronizar
      final hasConnection = await _syncService.hasConnection();
      if (!hasConnection) {
        _error = 'Sin conexión a internet. No se puede sincronizar.';
        _isOffline = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Si hay catálogos que recargar después de sincronizar
      if (userId != null) {
        await _syncService.syncCatalogsFromServer(
          userId: userId,
          isAdmin: isAdmin ?? false,
          userEmail: userEmail,
        );
      }

      // Sincronizar operaciones pendientes
      await _syncService.syncPendingOperations();

      // Recargar catálogos para reflejar cambios
      if (userId != null) {
        _catalogs = await _syncService.getCatalogs(
          userId: userId,
          isAdmin: isAdmin ?? false,
          userEmail: userEmail,
        );
      }

      _isOffline = false;
      _error = null;
    } catch (e) {
      _error = 'Error en sincronización: $e';
      print('❌ Error sincronizando: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
