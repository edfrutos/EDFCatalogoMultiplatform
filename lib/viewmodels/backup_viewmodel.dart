import 'package:flutter/foundation.dart';
import '../services/google_drive_backup_service.dart';
import '../services/project_backup_service.dart';
import '../models/backup_info.dart';

/// ViewModel para gestionar backups (Google Drive, Local y Proyecto)
class BackupViewModel extends ChangeNotifier {
  final GoogleDriveBackupService _googleDriveService =
      GoogleDriveBackupService();
  final ProjectBackupService _projectBackupService = ProjectBackupService();

  List<BackupInfo> _catalogBackups = [];
  List<BackupInfo> _userBackups = [];
  List<ProjectBackupInfo> _projectBackups = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  BackupType? _selectedType;

  List<BackupInfo> get catalogBackups => _catalogBackups;
  List<BackupInfo> get userBackups => _userBackups;
  List<ProjectBackupInfo> get projectBackups => _projectBackups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  BackupType? get selectedType => _selectedType;

  /// Cargar lista de backups
  Future<void> loadBackups({
    BackupType? type,
    bool loadProjectBackups = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Solo cargar backups de Google Drive si se solicita explícitamente
      // (no inicializar Google Drive si solo queremos backups del proyecto)
      if (type == BackupType.catalogs ||
          (type == null && !loadProjectBackups)) {
        try {
          if (!_googleDriveService.isInitialized) {
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _catalogBackups = await _googleDriveService.listCatalogBackups();
        } catch (e) {
          print('⚠️ Error cargando backups de Google Drive: $e');
          // Continuar con backups locales
        }
      }

      if (type == BackupType.users || (type == null && !loadProjectBackups)) {
        try {
          if (!_googleDriveService.isInitialized) {
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _userBackups = await _googleDriveService.listUserBackups();
        } catch (e) {
          print('⚠️ Error cargando backups de Google Drive: $e');
        }
      }

      // Cargar backups del proyecto solo si se solicita
      if (loadProjectBackups) {
        _projectBackups = await _projectBackupService.listProjectBackups();
      }
    } catch (e) {
      _errorMessage = 'Error al cargar backups: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crear backup de catálogos (Google Drive)
  Future<void> createCatalogBackup() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      await _googleDriveService.backupCatalogs();
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

  /// Crear backup de usuarios (Google Drive)
  Future<void> createUserBackup() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      await _googleDriveService.backupUsers();
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

  /// Crear backup del proyecto completo
  /// [backupDirectory] - Directorio donde guardar el backup (si es null, intentará usar el predeterminado)
  /// [projectPath] - Ruta del proyecto a hacer backup (si es null, usa la ruta predeterminada)
  /// [uploadToGoogleDrive] - Si es true, también subirá el backup a Google Drive
  Future<void> createProjectBackup({
    String? backupDirectory,
    String? projectPath,
    bool uploadToGoogleDrive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      String? selectedDir = backupDirectory;

      // Si no se proporciona directorio y falla por permisos, pedir al usuario que seleccione
      try {
        final backupInfo = await _projectBackupService.createProjectBackup(
          backupDirectory: selectedDir,
          projectPath: projectPath,
        );

        String message =
            'Backup del proyecto creado correctamente\n'
            'Ubicación: ${backupInfo.backupPath}\n'
            'Archivos: ${backupInfo.filesCount}\n'
            'Tamaño: ${backupInfo.sizeFormatted}';

        // Subir a Google Drive si está habilitado y existe el ZIP
        if (uploadToGoogleDrive && backupInfo.zipPath != null) {
          try {
            // Inicializar Google Drive si no está inicializado
            if (!_googleDriveService.isInitialized) {
              await _googleDriveService.initialize(
                onAuthUrl: (url) {
                  print('🔗 Abriendo URL de autenticación: $url');
                },
              );
            }

            print('📤 Subiendo backup del proyecto a Google Drive...');
            final driveFileId = await _googleDriveService.uploadProjectBackup(
              backupInfo.zipPath!,
            );
            message += '\n✅ Subido a Google Drive (ID: $driveFileId)';
            print('✅ Backup del proyecto subido a Google Drive');
          } catch (e) {
            print('⚠️ Error subiendo a Google Drive: $e');
            message += '\n⚠️ No se pudo subir a Google Drive: $e';
            // Continuar aunque falle la subida a Google Drive
          }
        }

        _successMessage = message;

        // Recargar backups del proyecto
        await loadBackups(loadProjectBackups: true);
      } catch (e) {
        // Si el error menciona permisos, lanzar excepción para que la UI maneje
        // (Ya no intentamos crear ZIP en memoria porque también necesita permisos de lectura)
        if (e.toString().contains('permisos') ||
            e.toString().contains('permission') ||
            e.toString().contains('Operation not permitted')) {
          rethrow; // Re-lanzar para que la UI maneje el diálogo de selección
        }
        throw e;
      }
    } catch (e) {
      _errorMessage = 'Error al crear backup del proyecto: $e';
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
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize();
      }

      final data = await _googleDriveService.downloadBackup(fileId);
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

  /// Eliminar un backup (Google Drive)
  Future<void> deleteBackup(String fileId, BackupType type) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize();
      }

      await _googleDriveService.deleteBackup(fileId);
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

  /// Eliminar un backup del proyecto
  Future<void> deleteProjectBackup(String backupPath) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _projectBackupService.deleteProjectBackup(backupPath);
      _successMessage = 'Backup del proyecto eliminado correctamente';

      // Recargar lista de backups
      await loadBackups();
    } catch (e) {
      _errorMessage = 'Error al eliminar backup del proyecto: $e';
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
