import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../services/google_drive_backup_service.dart';
import '../services/project_backup_service.dart';
import '../services/mongo_service.dart';
import '../models/backup_info.dart';
import '../models/catalog.dart';

/// ViewModel para gestionar backups (Google Drive, Local y Proyecto)
class BackupViewModel extends ChangeNotifier {
  final GoogleDriveBackupService _googleDriveService =
      GoogleDriveBackupService();
  final ProjectBackupService _projectBackupService = ProjectBackupService();

  List<BackupInfo> _catalogBackups = [];
  List<BackupInfo> _userBackups = [];
  List<BackupInfo> _projectBackups = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  BackupType? _selectedType;
  bool _isDisposed = false;

  List<BackupInfo> get catalogBackups => _catalogBackups;
  List<BackupInfo> get userBackups => _userBackups;
  List<BackupInfo> get projectBackups => _projectBackups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  BackupType? get selectedType => _selectedType;

  /// Cargar lista de backups
  Future<void> loadBackups({
    BackupType? type,
    bool loadProjectBackups = true,
  }) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      print(
        '📋 Cargando backups - type: $type, loadProjectBackups: $loadProjectBackups',
      );

      // Cargar backups de Google Drive según el tipo
      if (type == BackupType.catalogs) {
        print('📂 Cargando backups de catálogos desde Google Drive...');
        try {
          if (!_googleDriveService.isInitialized) {
            print('🔧 Inicializando Google Drive Service...');
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _catalogBackups = await _googleDriveService.listCatalogBackups();
          print('✅ Backups de catálogos cargados: ${_catalogBackups.length}');
        } catch (e, stackTrace) {
          print('❌ Error cargando backups de catálogos desde Google Drive: $e');
          print('   Stack trace: $stackTrace');
          _catalogBackups = [];
        }
      } else if (type == BackupType.users) {
        print('👥 Cargando backups de usuarios desde Google Drive...');
        try {
          if (!_googleDriveService.isInitialized) {
            print('🔧 Inicializando Google Drive Service...');
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _userBackups = await _googleDriveService.listUserBackups();
          print('✅ Backups de usuarios cargados: ${_userBackups.length}');
        } catch (e, stackTrace) {
          print('❌ Error cargando backups de usuarios desde Google Drive: $e');
          print('   Stack trace: $stackTrace');
          _userBackups = [];
        }
      } else if (type == BackupType.project) {
        print('📁 Cargando backups de proyectos desde Google Drive...');
        try {
          if (!_googleDriveService.isInitialized) {
            print('🔧 Inicializando Google Drive Service...');
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _projectBackups = await _googleDriveService.listProjectBackups();
          print('✅ Backups de proyectos cargados: ${_projectBackups.length}');
        } catch (e, stackTrace) {
          print('❌ Error cargando backups de proyectos desde Google Drive: $e');
          print('   Stack trace: $stackTrace');
          _projectBackups = [];
        }
      }

      // Cargar backups del proyecto SOLO si se solicita explícitamente (compatibilidad con código antiguo)
      if (loadProjectBackups && type != BackupType.project) {
        print(
          '⚠️ loadProjectBackups=true pero type != project, usando Google Drive en su lugar',
        );
        // Usar Google Drive en lugar del directorio local
        try {
          if (!_googleDriveService.isInitialized) {
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }
          _projectBackups = await _googleDriveService.listProjectBackups();
          print(
            '✅ Backups de proyectos cargados desde Google Drive: ${_projectBackups.length}',
          );
        } catch (e, stackTrace) {
          print('❌ Error cargando backups de proyectos: $e');
          print('   Stack trace: $stackTrace');
          _projectBackups = [];
        }
      }
    } catch (e) {
      _errorMessage = 'Error al cargar backups: $e';
      // ignore: avoid_print
      print('❌ Error: $_errorMessage');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Crear backup de catálogos (Google Drive)
  Future<void> createCatalogBackup() async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

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

      // Recargar lista de backups (solo de catálogos, no del proyecto)
      await loadBackups(type: BackupType.catalogs, loadProjectBackups: false);
    } catch (e) {
      _errorMessage = 'Error al crear backup de catálogos: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Crear backup de usuarios (Google Drive)
  Future<void> createUserBackup() async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

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

      // Recargar lista de backups (solo de usuarios, no del proyecto)
      await loadBackups(type: BackupType.users, loadProjectBackups: false);
    } catch (e) {
      _errorMessage = 'Error al crear backup de usuarios: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Crear backup del proyecto completo
  /// [backupDirectory] - Directorio donde guardar el backup localmente (si es null, intentará usar Google Drive primero)
  /// [projectPath] - Ruta del proyecto a hacer backup (si es null, usa la ruta predeterminada)
  /// [uploadToGoogleDrive] - Si es true, intentará subir a Google Drive primero (por defecto)
  Future<void> createProjectBackup({
    String? backupDirectory,
    String? projectPath,
    bool uploadToGoogleDrive = true,
  }) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      // POR DEFECTO: Intentar crear backup directamente en Google Drive (en memoria)
      // Esto evita problemas de permisos del sandbox de macOS
      if (uploadToGoogleDrive && backupDirectory == null) {
        try {
          print('📤 Intentando crear backup directamente en Google Drive...');

          // Inicializar Google Drive si no está inicializado
          if (!_googleDriveService.isInitialized) {
            await _googleDriveService.initialize(
              onAuthUrl: (url) {
                print('🔗 Abriendo URL de autenticación: $url');
              },
            );
          }

          // Crear ZIP en memoria y subirlo directamente a Google Drive
          final zipData = await _projectBackupService.createProjectZipInMemory(
            projectPath: projectPath,
          );
          final zipBytes = zipData['bytes'] as List<int>;
          final fileName = zipData['fileName'] as String;
          final filesCount = zipData['filesCount'] as int;
          final sizeBytes = zipData['sizeBytes'] as int;

          print(
            '📤 Subiendo backup del proyecto directamente a Google Drive...',
          );
          final driveFileId = await _googleDriveService
              .uploadProjectBackupFromBytes(zipBytes, fileName);

          _successMessage =
              '✅ Backup del proyecto creado y subido a Google Drive\n'
              'Archivos: $filesCount\n'
              'Tamaño: ${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB\n'
              'ID en Google Drive: $driveFileId';

          print('✅ Backup del proyecto subido a Google Drive');

          // Recargar backups del proyecto solo si el ViewModel no se ha disposeado
          if (!_isDisposed) {
            await loadBackups(type: BackupType.project);
          }
          return; // Éxito, salir
        } catch (e) {
          print('⚠️ Error subiendo a Google Drive: $e');
          // Si falla por permisos, re-lanzar para que la UI maneje la selección de directorio
          if (e.toString().contains('permisos') ||
              e.toString().contains('permission') ||
              e.toString().contains('Operation not permitted') ||
              e.toString().contains('PathAccessException') ||
              e.toString().contains('No se puede acceder')) {
            rethrow;
          }
          // Si falla por otra razón, intentar guardar localmente como fallback
          // Continuar con el flujo local
        }
      }

      // FALLBACK: Guardar localmente (si se especificó backupDirectory o si Google Drive falló)
      String? selectedDir = backupDirectory;

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

        // Recargar backups del proyecto solo si el ViewModel no se ha disposeado
        if (!_isDisposed) {
          await loadBackups(type: BackupType.project);
        }
      } catch (e) {
        // Si el error menciona permisos, lanzar excepción para que la UI maneje
        if (e.toString().contains('permisos') ||
            e.toString().contains('permission') ||
            e.toString().contains('Operation not permitted') ||
            e.toString().contains('No se puede acceder')) {
          rethrow; // Re-lanzar para que la UI maneje el diálogo de selección
        }
        throw e;
      }
    } catch (e) {
      _errorMessage = 'Error al crear backup del proyecto: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      // Solo notificar si el ViewModel no se ha disposeado
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Descargar un backup (sin restaurar, solo obtener datos)
  /// Para catálogos/usuarios: retorna JSON
  /// Para proyectos: retorna bytes del ZIP (en el campo 'bytes')
  Future<Map<String, dynamic>?> downloadBackup(
    String fileId,
    BackupType type,
  ) async {
    if (_isDisposed) return null;
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize();
      }

      if (type == BackupType.project) {
        // Para proyectos, descargar como ZIP
        final zipBytes = await _googleDriveService.downloadProjectBackup(
          fileId,
        );
        return {'bytes': zipBytes, 'type': 'zip'};
      } else {
        // Para catálogos/usuarios, descargar como JSON
        final data = await _googleDriveService.downloadBackup(fileId);
        return data;
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = 'Error al descargar backup: $e';
        print('❌ Error: $_errorMessage');
      }
      return null;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Eliminar un backup (Google Drive)
  Future<void> deleteBackup(String fileId, BackupType type) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize();
      }

      await _googleDriveService.deleteBackup(fileId);
      if (!_isDisposed) {
        _successMessage = 'Backup eliminado correctamente';
        // Recargar lista de backups
        await loadBackups(type: type);
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = 'Error al eliminar backup: $e';
        print('❌ Error: $_errorMessage');
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Restaurar backup de catálogos
  Future<void> restoreCatalogBackup(String fileId) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      // Descargar backup
      final backupData = await _googleDriveService.downloadBackup(fileId);

      // Validar estructura del backup
      if (backupData['catalogs'] == null ||
          backupData['catalogs'] is! List<dynamic>) {
        throw Exception(
          'Formato de backup inválido: no se encontraron catálogos',
        );
      }

      final catalogsJson = backupData['catalogs'] as List<dynamic>;
      final mongoService = MongoService();

      // Restaurar cada catálogo
      int restored = 0;
      int updated = 0;
      int skipped = 0;
      int errors = 0;

      for (final catalogJson in catalogsJson) {
        try {
          if (catalogJson is! Map<String, dynamic>) {
            print('⚠️ Catálogo inválido en backup, saltando...');
            skipped++;
            continue;
          }

          final catalogData = Map<String, dynamic>.from(catalogJson);

          // Obtener información del catálogo del backup
          final catalogName = catalogData['Name'] ?? catalogData['name'] ?? '';
          final backupUserId =
              catalogData['Owner'] ??
              catalogData['CreatedBy'] ??
              catalogData['userId'] ??
              '';
          final backupUpdatedAtStr =
              catalogData['UpdatedAt'] ??
              catalogData['updatedAt'] ??
              catalogData['CreatedAt'] ??
              catalogData['createdAt'];

          DateTime? backupUpdatedAt;
          if (backupUpdatedAtStr != null) {
            try {
              backupUpdatedAt = DateTime.parse(backupUpdatedAtStr.toString());
            } catch (e) {
              print('⚠️ Error parseando fecha del backup: $e');
            }
          }

          // Buscar catálogo existente por nombre y userId
          Catalog? existingCatalog;
          if (catalogName.isNotEmpty && backupUserId.toString().isNotEmpty) {
            try {
              final allCatalogs = await mongoService.getCatalogs(
                backupUserId.toString(),
                isAdmin: true, // Necesitamos acceso admin para buscar todos
              );

              // Buscar por nombre exacto y mismo propietario
              existingCatalog = allCatalogs.firstWhere(
                (c) =>
                    c.name == catalogName &&
                    (c.userId == backupUserId.toString() ||
                        c.userId.contains(backupUserId.toString())),
                orElse: () => throw StateError('No encontrado'),
              );
            } catch (e) {
              // No existe, continuar para crear nuevo
              existingCatalog = null;
            }
          }

          if (existingCatalog != null) {
            // Comparar timestamps: si el backup es más reciente, actualizar
            if (backupUpdatedAt != null &&
                backupUpdatedAt.isAfter(existingCatalog.updatedAt)) {
              print(
                '🔄 Catálogo existente encontrado (${existingCatalog.name}), '
                'backup es más reciente. Actualizando...',
              );

              // Construir el catálogo desde el backup
              final backupCatalog = Catalog.fromJson(catalogData);

              // Actualizar el catálogo existente
              final updates = <String, dynamic>{
                'Name': backupCatalog.name,
                'Description': backupCatalog.description,
                'Headers': backupCatalog.columns,
                'Rows': backupCatalog.rows.map((row) => row.toJson()).toList(),
                'UpdatedAt': backupUpdatedAt.toIso8601String(),
              };

              await mongoService.updateCatalog(existingCatalog.id, updates);
              updated++;
              print('✅ Catálogo actualizado: ${catalogName}');
            } else {
              print(
                '⏭️  Catálogo existente (${existingCatalog.name}) es más reciente o igual. '
                'Manteniendo versión existente.',
              );
              skipped++;
            }
          } else {
            // No existe, crear nuevo catálogo
            // Limpiar el ID del catálogo para que MongoDB genere uno nuevo
            catalogData.remove('_id');
            catalogData.remove('id');

            // Mantener timestamps del backup si están disponibles
            if (backupUpdatedAt != null) {
              catalogData['UpdatedAt'] = backupUpdatedAt.toIso8601String();
            } else {
              final now = DateTime.now();
              catalogData['UpdatedAt'] = now.toIso8601String();
            }

            if (catalogData['CreatedAt'] == null) {
              final now = DateTime.now();
              catalogData['CreatedAt'] = now.toIso8601String();
            }

            // Crear catálogo en MongoDB
            await mongoService.createCatalogFromMap(catalogData);
            restored++;
            print('✅ Catálogo restaurado (nuevo): ${catalogName}');
          }
        } catch (e) {
          print('❌ Error restaurando catálogo: $e');
          errors++;
        }
      }

      _successMessage =
          '✅ Backup restaurado correctamente\n'
          'Catálogos nuevos: $restored\n'
          'Catálogos actualizados: $updated\n'
          'Omitidos: $skipped\n'
          'Errores: $errors';

      print(
        '✅ Restauración completada: $restored nuevos, $updated actualizados, $skipped omitidos, $errors errores',
      );
    } catch (e) {
      _errorMessage = 'Error al restaurar backup de catálogos: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Restaurar backup de usuarios
  Future<void> restoreUserBackup(String fileId) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      if (!_googleDriveService.isInitialized) {
        await _googleDriveService.initialize(
          onAuthUrl: (url) {
            print('🔗 Abriendo URL de autenticación: $url');
          },
        );
      }

      // Descargar backup
      final backupData = await _googleDriveService.downloadBackup(fileId);

      // Validar estructura del backup
      if (backupData['users'] == null ||
          backupData['users'] is! List<dynamic>) {
        throw Exception(
          'Formato de backup inválido: no se encontraron usuarios',
        );
      }

      final usersJson = backupData['users'] as List<dynamic>;
      final mongoService = MongoService();

      // Restaurar cada usuario
      int restored = 0;
      int skipped = 0;
      int errors = 0;

      for (final userJson in usersJson) {
        try {
          if (userJson is! Map<String, dynamic>) {
            print('⚠️ Usuario inválido en backup, saltando...');
            skipped++;
            continue;
          }

          // Verificar si el usuario ya existe por email
          final email = userJson['Email'] ?? userJson['email'];
          if (email == null || email.toString().isEmpty) {
            print('⚠️ Usuario sin email, saltando...');
            skipped++;
            continue;
          }

          final existingUser = await mongoService.getUserByEmail(
            email.toString(),
          );
          if (existingUser != null) {
            print('⚠️ Usuario ya existe: $email, saltando...');
            skipped++;
            continue;
          }

          // Limpiar el ID del usuario para que MongoDB genere uno nuevo
          final userData = Map<String, dynamic>.from(userJson);
          userData.remove('_id');
          userData.remove('id');

          // Validar campos requeridos
          final username = userData['Username'] ?? userData['username'] ?? '';
          final name = userData['Name'] ?? userData['name'] ?? '';
          final password = userData['Password'] ?? userData['password'] ?? '';

          if (username.toString().isEmpty || password.toString().isEmpty) {
            print('⚠️ Usuario sin username o password, saltando...');
            skipped++;
            continue;
          }

          // Crear usuario en MongoDB (usando createUser que hace el hash de la contraseña)
          // Si el backup tiene passwordHash, necesitamos crear el usuario directamente
          if (userData.containsKey('Password') ||
              userData.containsKey('passwordHash')) {
            // Si tiene hash, usar inserción directa
            final collection = await mongoService.getUsersCollection();
            final userDoc = {
              '_id': mongo.ObjectId().toString(),
              'Email': email.toString(),
              'Username': username.toString(),
              'Name': name.toString(),
              'Password': password.toString(), // Ya viene hasheado del backup
              'Role': userData['Role'] ?? userData['role'] ?? 'user',
              'IsActive': userData['IsActive'] ?? userData['isActive'] ?? true,
              'CreatedAt': DateTime.now().toIso8601String(),
            };
            await collection.insertOne(userDoc);
          } else {
            // Si no tiene hash, crear usuario nuevo (generará nueva contraseña)
            // En este caso, no podemos restaurar usuarios sin contraseña
            print('⚠️ Usuario sin contraseña en backup, saltando...');
            skipped++;
            continue;
          }

          restored++;
          print('✅ Usuario restaurado: $email');
        } catch (e) {
          print('❌ Error restaurando usuario: $e');
          errors++;
        }
      }

      _successMessage =
          '✅ Backup restaurado correctamente\n'
          'Usuarios restaurados: $restored\n'
          'Omitidos: $skipped\n'
          'Errores: $errors';

      print(
        '✅ Restauración completada: $restored restaurados, $skipped omitidos, $errors errores',
      );
    } catch (e) {
      _errorMessage = 'Error al restaurar backup de usuarios: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Eliminar un backup del proyecto
  Future<void> deleteProjectBackup(String backupPath) async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      await _projectBackupService.deleteProjectBackup(backupPath);
      if (!_isDisposed) {
        _successMessage = 'Backup del proyecto eliminado correctamente';
        // Recargar lista de backups
        await loadBackups();
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = 'Error al eliminar backup del proyecto: $e';
        print('❌ Error: $_errorMessage');
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Limpiar mensajes
  void clearMessages() {
    if (_isDisposed) return;
    _errorMessage = null;
    _successMessage = null;
    if (!_isDisposed) notifyListeners();
  }

  /// Seleccionar tipo de backup
  void selectType(BackupType? type) {
    if (_isDisposed) return;
    _selectedType = type;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
