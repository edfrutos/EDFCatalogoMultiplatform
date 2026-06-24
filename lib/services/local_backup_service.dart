import 'dart:convert';
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import 'package:path/path.dart' as path;
import '../services/mongo_service.dart';
// ignore: unused_import
import '../models/catalog.dart';
// ignore: unused_import
import '../models/user.dart';

/// Información de un backup local
class LocalBackupInfo {
  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final BackupType type;

  LocalBackupInfo({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    required this.type,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Tipo de backup
enum BackupType { catalogs, users }

/// Servicio para gestionar backups locales en el sistema de archivos
class LocalBackupService {
  static final LocalBackupService _instance = LocalBackupService._internal();
  factory LocalBackupService() => _instance;
  LocalBackupService._internal();

  static final String _backupBasePath = _resolveBackupBasePath();
  static const String _catalogsFolder = 'catalogs';
  static const String _usersFolder = 'users';

  /// Verificar y crear la estructura de directorios si no existe
  Future<void> _ensureDirectoriesExist() async {
    try {
      final baseDir = Directory(_backupBasePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
        print('📁 Directorio de backups creado: $_backupBasePath');
      }

      final catalogsDir = Directory('$_backupBasePath/$_catalogsFolder');
      if (!await catalogsDir.exists()) {
        await catalogsDir.create(recursive: true);
      }

      final usersDir = Directory('$_backupBasePath/$_usersFolder');
      if (!await usersDir.exists()) {
        await usersDir.create(recursive: true);
      }
    } catch (e) {
      print('❌ Error creando directorios de backup: $e');
      rethrow;
    }
  }

  /// Crear backup de todos los catálogos
  Future<LocalBackupInfo> backupCatalogs() async {
    try {
      await _ensureDirectoriesExist();

      final mongoService = MongoService();
      final catalogs = await mongoService.getCatalogs(
        '', // userId vacío
        isAdmin: true, // true para obtener todos
      );

      // Convertir catálogos a JSON
      final catalogsJson = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'count': catalogs.length,
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
      };

      final jsonString = json.encode(catalogsJson);
      final jsonBytes = utf8.encode(jsonString);

      // Generar nombre del archivo
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'catalogs_backup_$timestamp.json';
      final filePath = '$_backupBasePath/$_catalogsFolder/$fileName';

      // Guardar archivo
      final file = File(filePath);
      await file.writeAsBytes(jsonBytes);

      print('✅ Backup de catálogos creado: $filePath');
      print('   Catálogos guardados: ${catalogs.length}');
      print('   Tamaño: ${(jsonBytes.length / 1024).toStringAsFixed(2)} KB');

      return LocalBackupInfo(
        fileName: fileName,
        filePath: filePath,
        createdAt: DateTime.now(),
        sizeBytes: jsonBytes.length,
        type: BackupType.catalogs,
      );
    } catch (e) {
      print('❌ Error creando backup de catálogos: $e');
      rethrow;
    }
  }

  /// Crear backup de todos los usuarios (sin contraseñas)
  Future<LocalBackupInfo> backupUsers() async {
    try {
      await _ensureDirectoriesExist();

      final mongoService = MongoService();
      final users = await mongoService.getAllUsers();

      // Convertir usuarios a JSON (sin contraseñas)
      final usersJson = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'count': users.length,
        'users': users.map((u) {
          final userMap = u.toJson();
          // Eliminar contraseña del JSON
          userMap.remove('password');
          return userMap;
        }).toList(),
      };

      final jsonString = json.encode(usersJson);
      final jsonBytes = utf8.encode(jsonString);

      // Generar nombre del archivo
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'users_backup_$timestamp.json';
      final filePath = '$_backupBasePath/$_usersFolder/$fileName';

      // Guardar archivo
      final file = File(filePath);
      await file.writeAsBytes(jsonBytes);

      print('✅ Backup de usuarios creado: $filePath');
      print('   Usuarios guardados: ${users.length}');
      print('   Tamaño: ${(jsonBytes.length / 1024).toStringAsFixed(2)} KB');

      return LocalBackupInfo(
        fileName: fileName,
        filePath: filePath,
        createdAt: DateTime.now(),
        sizeBytes: jsonBytes.length,
        type: BackupType.users,
      );
    } catch (e) {
      print('❌ Error creando backup de usuarios: $e');
      rethrow;
    }
  }

  /// Listar todos los backups de catálogos
  Future<List<LocalBackupInfo>> listCatalogBackups() async {
    try {
      final catalogsDir = Directory('$_backupBasePath/$_catalogsFolder');
      if (!await catalogsDir.exists()) {
        return [];
      }

      final backups = <LocalBackupInfo>[];
      await for (final entity in catalogsDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final stat = await entity.stat();
            final fileName = entity.path.split('/').last;
            backups.add(
              LocalBackupInfo(
                fileName: fileName,
                filePath: entity.path,
                createdAt: stat.modified,
                sizeBytes: stat.size,
                type: BackupType.catalogs,
              ),
            );
          } catch (e) {
            print('⚠️ Error leyendo archivo ${entity.path}: $e');
          }
        }
      }

      // Ordenar por fecha (más reciente primero)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      print('❌ Error listando backups de catálogos: $e');
      return [];
    }
  }

  /// Listar todos los backups de usuarios
  Future<List<LocalBackupInfo>> listUserBackups() async {
    try {
      final usersDir = Directory('$_backupBasePath/$_usersFolder');
      if (!await usersDir.exists()) {
        return [];
      }

      final backups = <LocalBackupInfo>[];
      await for (final entity in usersDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final stat = await entity.stat();
            final fileName = entity.path.split('/').last;
            backups.add(
              LocalBackupInfo(
                fileName: fileName,
                filePath: entity.path,
                createdAt: stat.modified,
                sizeBytes: stat.size,
                type: BackupType.users,
              ),
            );
          } catch (e) {
            print('⚠️ Error leyendo archivo ${entity.path}: $e');
          }
        }
      }

      // Ordenar por fecha (más reciente primero)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      print('❌ Error listando backups de usuarios: $e');
      return [];
    }
  }

  /// Descargar/leer un backup (retorna el contenido JSON)
  Future<Map<String, dynamic>?> downloadBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('El archivo de backup no existe: $filePath');
      }

      final content = await file.readAsString();
      final jsonData = json.decode(content) as Map<String, dynamic>;

      return jsonData;
    } catch (e) {
      print('❌ Error descargando backup: $e');
      rethrow;
    }
  }

  /// Eliminar un backup
  Future<void> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Backup eliminado: $filePath');
      } else {
        throw Exception('El archivo de backup no existe: $filePath');
      }
    } catch (e) {
      print('❌ Error eliminando backup: $e');
      rethrow;
    }
  }

  /// Obtener la ruta base de backups
  String get backupBasePath => _backupBasePath;

  static String _resolveBackupBasePath() {
    final override = _readEnvOverrides(
      keys: const ['EDF_BACKUP_DIR', 'EDF_BACKUPS_DIR'],
    );
    if (override != null) {
      return path.normalize(override);
    }

    final homeDir = Platform.environment['HOME'];
    if (homeDir != null && homeDir.isNotEmpty) {
      return path.normalize(path.join(homeDir, 'EDFCatalogoBackups'));
    }

    return path.normalize(path.join(Directory.current.path, 'EDFCatalogoBackups'));
  }

  static String? _readEnvOverrides({required List<String> keys}) {
    for (final key in keys) {
      final value = Platform.environment[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
