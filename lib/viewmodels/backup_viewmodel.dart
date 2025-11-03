import 'package:flutter/foundation.dart';
import '../services/google_drive_backup_service.dart';

/// ViewModel para gestionar backups
class BackupViewModel extends ChangeNotifier {
  final GoogleDriveBackupService _backupService = GoogleDriveBackupService();

  List<BackupInfo> _catalogBackups = [];
  List<BackupInfo> _userBackups = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  BackupType? _selectedType;

  List<BackupInfo> get catalogBackups => _catalogBackups;
  List<BackupInfo> get userBackups => _userBackups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  BackupType? get selectedType => _selectedType;

  /// Cargar lista de backups
  Future<void> loadBackups({BackupType? type}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Inicializar servicio si es necesario
      if (!_backupService.isInitialized) {
        await _backupService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      if (type == null || type == BackupType.catalogs) {
        _catalogBackups = await _backupService.listCatalogBackups();
      }

      if (type == null || type == BackupType.users) {
        _userBackups = await _backupService.listUserBackups();
      }
    } catch (e) {
      _errorMessage = 'Error al cargar backups: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crear backup de catálogos
  Future<void> createCatalogBackup() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_backupService.isInitialized) {
        await _backupService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      await _backupService.backupCatalogs();
      _successMessage =
          'Backup de catálogos creado correctamente en Google Drive';

      // Recargar lista de backups
      await loadBackups(type: BackupType.catalogs);
    } catch (e) {
      _errorMessage = 'Error al crear backup de catálogos: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crear backup de usuarios
  Future<void> createUserBackup() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_backupService.isInitialized) {
        await _backupService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      await _backupService.backupUsers();
      _successMessage =
          'Backup de usuarios creado correctamente en Google Drive';

      // Recargar lista de backups
      await loadBackups(type: BackupType.users);
    } catch (e) {
      _errorMessage = 'Error al crear backup de usuarios: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Descargar un backup (sin restaurar, solo obtener datos)
  Future<Map<String, dynamic>?> downloadBackup(
    String fileId,
    BackupType type,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_backupService.isInitialized) {
        await _backupService.initialize();
      }

      final data = await _backupService.downloadBackup(fileId);
      return data;
    } catch (e) {
      _errorMessage = 'Error al descargar backup: $e';
      print('❌ Error: $_errorMessage');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar un backup
  Future<void> deleteBackup(String fileId, BackupType type) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_backupService.isInitialized) {
        await _backupService.initialize();
      }

      await _backupService.deleteBackup(fileId);
      _successMessage = 'Backup eliminado correctamente';

      // Recargar lista de backups
      await loadBackups(type: type);
    } catch (e) {
      _errorMessage = 'Error al eliminar backup: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpiar mensajes
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Seleccionar tipo de backup
  void selectType(BackupType? type) {
    _selectedType = type;
    notifyListeners();
  }
}
