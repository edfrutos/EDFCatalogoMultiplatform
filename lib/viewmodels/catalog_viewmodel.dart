import 'package:flutter/foundation.dart';
import '../models/catalog.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';

class CatalogViewModel extends ChangeNotifier {
  final SyncService _syncService = SyncService.shared;
  final LocalStorageService _localStorage = LocalStorageService.shared;

  List<Catalog> _catalogs = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;

  List<Catalog> get catalogs => _catalogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;

  Future<void> loadCatalogs({
    required String userId,
    required bool isAdmin,
    String? userEmail,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Verificar conexión
      final hasConnection = await _syncService.hasConnection();
      _isOffline = !hasConnection;

      if (hasConnection) {
        // Intentar sincronizar desde servidor
        await _syncService.syncCatalogsFromServer(
          userId: userId,
          isAdmin: isAdmin,
          userEmail: userEmail,
        );
      }

      // Obtener catálogos (desde servidor si hay conexión, sino desde local)
      _catalogs = await _syncService.getCatalogs(
        userId: userId,
        isAdmin: isAdmin,
        userEmail: userEmail,
      );

      _error = null;

      // Si hay operaciones pendientes y hay conexión, sincronizar
      if (hasConnection && await _localStorage.hasPendingSync()) {
        _syncService.syncPendingOperations();
      }
    } catch (e) {
      _error = 'No se pudieron cargar los catálogos: $e';
      // Fallback a datos locales
      try {
        _catalogs = await _localStorage.loadCatalogsLocally();
        _isOffline = true;
      } catch (_) {
        // Si también falla la carga local, dejar error
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
  Future<void> syncPendingData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _syncService.syncPendingOperations();
      _error = null;
    } catch (e) {
      _error = 'Error en sincronización: $e';
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
