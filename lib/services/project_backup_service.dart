import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// Información de un backup del proyecto
class ProjectBackupInfo {
  final String backupName;
  final String backupPath;
  final String? zipPath; // Ruta del archivo ZIP comprimido
  final DateTime createdAt;
  final int sizeBytes;
  final int filesCount;

  ProjectBackupInfo({
    required this.backupName,
    required this.backupPath,
    this.zipPath,
    required this.createdAt,
    required this.sizeBytes,
    required this.filesCount,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Servicio para hacer backups del directorio del proyecto
class ProjectBackupService {
  static final ProjectBackupService _instance =
      ProjectBackupService._internal();
  factory ProjectBackupService() => _instance;
  ProjectBackupService._internal();

  static const String _backupBasePath =
      '/Users/edefrutos/__Proyectos/backups/EDFCatalogoMultiplatform';
  static const String _projectBackupsFolder = 'project_backups';

  // Directorios y archivos a excluir del backup
  // NOTA: Los archivos sensibles (.env, credenciales, etc.) SÍ se incluyen en el backup
  // Solo se excluyen archivos de build/compilación y temporales
  static const List<String> _excludedDirs = [
    'build',
    '.dart_tool',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    '.idea',
    '.vscode',
    '.git',
    'node_modules',
    'coverage',
    'ios/Pods',
    'android/.gradle',
    'android/app/build',
    'macos/Flutter/Flutter.framework',
    'macos/Flutter/FlutterMacOS.framework',
    'macos/Flutter/ephemeral',
    'windows/flutter/ephemeral',
    'linux/flutter/ephemeral',
    // Excluir directorio de backups para evitar recursión
    'backups',
  ];

  static const List<String> _excludedFiles = [
    '.DS_Store',
    // Los archivos sensibles (.env, credenciales, etc.) NO se excluyen
  ];

  static const List<String> _excludedPatterns = [
    r'\.log$',
    r'\.tmp$',
    r'\.bak$',
    r'\.swp$',
    r'\.swo$',
    r'\.class$',
    // Los archivos sensibles (.env, credenciales, etc.) NO se excluyen
  ];

  /// Verificar y crear el directorio de backups si no existe
  Future<void> _ensureBackupDirectoryExists() async {
    try {
      final backupDir = Directory(_backupBasePath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        print('📁 Directorio de backups creado: $_backupBasePath');
      }

      final projectBackupsDir = Directory(
        '$_backupBasePath/$_projectBackupsFolder',
      );
      if (!await projectBackupsDir.exists()) {
        await projectBackupsDir.create(recursive: true);
      }
    } catch (e) {
      print('❌ Error creando directorio de backups: $e');
      rethrow;
    }
  }

  /// Verificar si un directorio debe ser excluido
  bool _shouldExcludeDirectory(String dirName) {
    return _excludedDirs.contains(dirName);
  }

  /// Verificar si un archivo debe ser excluido
  bool _shouldExcludeFile(String fileName) {
    // Verificar patrones exactos
    if (_excludedFiles.contains(fileName)) return true;

    // Verificar patrones con wildcards
    for (final pattern in _excludedPatterns) {
      final regex = RegExp(pattern);
      if (regex.hasMatch(fileName)) return true;
    }

    return false;
  }

  /// Calcular el tamaño total de un directorio
  Future<int> _calculateDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      print('⚠️ Error calculando tamaño de ${dir.path}: $e');
    }
    return totalSize;
  }

  /// Contar archivos en un directorio
  Future<int> _countFiles(Directory dir) async {
    int count = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          count++;
        }
      }
    } catch (e) {
      print('⚠️ Error contando archivos en ${dir.path}: $e');
    }
    return count;
  }

  /// Copiar archivo o directorio al destino
  Future<void> _copyEntity(FileSystemEntity entity, String destPath) async {
    try {
      if (entity is File) {
        final destFile = File(destPath);
        final destDir = destFile.parent;
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        await entity.copy(destPath);
      } else if (entity is Directory) {
        final destDir = Directory(destPath);
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
      }
    } catch (e) {
      print('⚠️ Error copiando ${entity.path} a $destPath: $e');
      rethrow;
    }
  }

  /// Crear backup del proyecto completo
  /// [projectPath] - Ruta del proyecto a hacer backup (por defecto usa la ruta estándar)
  /// [backupDirectory] - Directorio donde guardar el backup (si es null, se pedirá al usuario)
  /// Nota: Si projectPath no tiene permisos de lectura, se lanzará una excepción
  Future<ProjectBackupInfo> createProjectBackup({
    String? projectPath,
    String? backupDirectory,
  }) async {
    try {
      // Determinar la ruta del proyecto
      final actualProjectPath =
          projectPath ??
          '/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform';
      final projectDir = Directory(actualProjectPath);

      if (!await projectDir.exists()) {
        throw Exception(
          'El directorio del proyecto no existe: $actualProjectPath',
        );
      }

      // Determinar el directorio de destino del backup
      String? selectedBackupDir = backupDirectory;

      // Si no se proporciona un directorio, usar el predeterminado
      // (pero intentar crear el directorio puede fallar por permisos)
      if (selectedBackupDir == null) {
        // Intentar usar el directorio predeterminado
        try {
          await _ensureBackupDirectoryExists();
          selectedBackupDir = '$_backupBasePath/$_projectBackupsFolder';
        } catch (e) {
          // Si falla por permisos, lanzar excepción con mensaje claro
          throw Exception(
            'No se puede crear el directorio de backup por falta de permisos.\n'
            'Por favor, selecciona un directorio donde guardar el backup.\n'
            'Error: $e',
          );
        }
      } else {
        // Verificar que el directorio proporcionado existe
        final dir = Directory(selectedBackupDir);
        if (!await dir.exists()) {
          // Intentar crear el directorio
          try {
            await dir.create(recursive: true);
          } catch (e) {
            throw Exception(
              'No se puede crear el directorio de backup: $selectedBackupDir\n'
              'Error: $e',
            );
          }
        }
      }

      // Verificar permisos para leer el directorio del proyecto ANTES de intentar hacer backup
      try {
        await projectDir.list().take(1).toList();
      } catch (e) {
        // Si no hay permisos para leer el directorio del proyecto, lanzar excepción clara
        if (e.toString().contains('Operation not permitted') ||
            e.toString().contains('permission') ||
            e.toString().contains('PathAccessException')) {
          throw Exception(
            'No se puede acceder al directorio del proyecto por falta de permisos.\n'
            'Por favor, selecciona el directorio del proyecto para otorgar permisos de lectura.\n'
            'Error: $e',
          );
        }
        rethrow;
      }

      // Generar nombre del backup con timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupName = 'project_backup_$timestamp';
      final backupPath = '$selectedBackupDir/$backupName';
      final backupDir = Directory(backupPath);

      if (await backupDir.exists()) {
        throw Exception('El directorio de backup ya existe: $backupPath');
      }

      await backupDir.create(recursive: true);

      print('📦 Iniciando backup del proyecto...');
      print('   Origen: $actualProjectPath');
      print('   Destino: $backupPath');

      int filesCopied = 0;
      int totalSize = 0;

      // Copiar archivos y directorios recursivamente
      await for (final entity in projectDir.list(recursive: false)) {
        final entityName = path.basename(entity.path);

        // Omitir directorios excluidos
        if (entity is Directory && _shouldExcludeDirectory(entityName)) {
          print('   ⏭️  Omitiendo directorio: $entityName');
          continue;
        }

        // Evitar copiar el directorio de backups si está dentro del proyecto
        final normalizedEntityPath = path.normalize(entity.path);
        final normalizedBackupBasePath = path.normalize(_backupBasePath);
        if (normalizedEntityPath.startsWith(normalizedBackupBasePath)) {
          print('   ⏭️  Omitiendo directorio de backups: $entityName');
          continue;
        }

        // Omitir archivos excluidos
        if (entity is File && _shouldExcludeFile(entityName)) {
          print('   ⏭️  Omitiendo archivo: $entityName');
          continue;
        }

        try {
          final relativePath = path.relative(
            entity.path,
            from: actualProjectPath,
          );
          final destPath = path.join(backupPath, relativePath);

          if (entity is File) {
            await _copyEntity(entity, destPath);
            final size = await entity.length();
            totalSize += size;
            filesCopied++;
            if (filesCopied % 100 == 0) {
              print('   📄 Archivos copiados: $filesCopied...');
            }
          } else if (entity is Directory) {
            // Copiar directorio recursivamente
            await _copyDirectoryRecursive(entity, destPath, actualProjectPath);

            // Contar archivos y calcular tamaño del directorio
            final dirSize = await _calculateDirectorySize(entity);
            final dirFiles = await _countFiles(entity);
            totalSize += dirSize;
            filesCopied += dirFiles;
          }
        } catch (e) {
          print('   ⚠️  Error copiando ${entity.path}: $e');
          // Continuar con el siguiente archivo
        }
      }

      print('✅ Backup del proyecto completado');
      print('   Archivos copiados: $filesCopied');
      print(
        '   Tamaño total: ${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
      print('   Ubicación: $backupPath');

      // Crear archivo ZIP del backup
      print('📦 Comprimiendo backup en ZIP...');
      final zipPath = await _createZipArchive(backupPath, backupName);
      print('✅ ZIP creado: $zipPath');

      return ProjectBackupInfo(
        backupName: backupName,
        backupPath: backupPath,
        zipPath: zipPath,
        createdAt: DateTime.now(),
        sizeBytes: totalSize,
        filesCount: filesCopied,
      );
    } catch (e) {
      print('❌ Error creando backup del proyecto: $e');
      rethrow;
    }
  }

  /// Copiar directorio recursivamente excluyendo archivos/directorios no deseados
  Future<void> _copyDirectoryRecursive(
    Directory sourceDir,
    String destPath,
    String projectRoot,
  ) async {
    try {
      final destDir = Directory(destPath);
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await for (final entity in sourceDir.list()) {
        final entityName = path.basename(entity.path);

        // Verificar si el directorio debe ser excluido
        if (entity is Directory && _shouldExcludeDirectory(entityName)) {
          continue;
        }

        // Verificar si el archivo debe ser excluido
        if (entity is File && _shouldExcludeFile(entityName)) {
          continue;
        }

        final relativePath = path.relative(entity.path, from: projectRoot);
        // Usar destPath directamente en lugar de reconstruirlo desde _backupBasePath
        // para evitar problemas de recursión
        final entityDestPath = path.join(destPath, relativePath);

        // Evitar copiar si el destino está dentro del origen (recursión)
        final normalizedSource = path.normalize(sourceDir.path);
        final normalizedDest = path.normalize(entityDestPath);
        if (normalizedDest.startsWith(normalizedSource)) {
          print(
            '⚠️  Evitando recursión: $entityDestPath está dentro de $normalizedSource',
          );
          continue;
        }

        if (entity is File) {
          await _copyEntity(entity, entityDestPath);
        } else if (entity is Directory) {
          await _copyDirectoryRecursive(entity, entityDestPath, projectRoot);
        }
      }
    } catch (e) {
      print('⚠️ Error copiando directorio ${sourceDir.path}: $e');
      rethrow;
    }
  }

  /// Listar todos los backups del proyecto
  /// [backupDirectory] - Directorio donde buscar backups (si es null, usa el predeterminado)
  Future<List<ProjectBackupInfo>> listProjectBackups({
    String? backupDirectory,
  }) async {
    try {
      final backupsDirPath =
          backupDirectory ?? '$_backupBasePath/$_projectBackupsFolder';
      final backupsDir = Directory(backupsDirPath);
      if (!await backupsDir.exists()) {
        return [];
      }

      // Verificar permisos antes de intentar listar
      try {
        await backupsDir.list().take(1).toList();
      } catch (e) {
        // Si no hay permisos para listar, retornar lista vacía sin error
        // (el usuario puede seleccionar un directorio diferente cuando cree un backup)
        if (e.toString().contains('Operation not permitted') ||
            e.toString().contains('permission')) {
          print('⚠️ No hay permisos para listar backups en: $backupsDirPath');
          return [];
        }
        rethrow;
      }

      final backups = <ProjectBackupInfo>[];
      await for (final entity in backupsDir.list()) {
        if (entity is Directory) {
          try {
            final backupName = path.basename(entity.path);
            final stat = await entity.stat();

            // Calcular tamaño y contar archivos
            final size = await _calculateDirectorySize(entity);
            final filesCount = await _countFiles(entity);

            backups.add(
              ProjectBackupInfo(
                backupName: backupName,
                backupPath: entity.path,
                createdAt: stat.modified,
                sizeBytes: size,
                filesCount: filesCount,
              ),
            );
          } catch (e) {
            print('⚠️ Error leyendo backup ${entity.path}: $e');
          }
        }
      }

      // Ordenar por fecha (más reciente primero)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      print('❌ Error listando backups del proyecto: $e');
      return [];
    }
  }

  /// Crear archivo ZIP del backup desde un directorio
  Future<String> _createZipArchive(
    String backupDirPath,
    String backupName,
  ) async {
    try {
      final backupDir = Directory(backupDirPath);
      if (!await backupDir.exists()) {
        throw Exception('El directorio de backup no existe: $backupDirPath');
      }

      final archive = Archive();

      // Añadir todos los archivos del directorio al ZIP
      await for (final entity in backupDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: backupDirPath);
          final fileBytes = await entity.readAsBytes();
          final archiveFile = ArchiveFile(
            relativePath,
            fileBytes.length,
            fileBytes,
          );
          archive.addFile(archiveFile);
        }
      }

      // Escribir el ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) {
        throw Exception('Error al crear el archivo ZIP');
      }

      final zipPath = '$backupDirPath.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes);

      return zipPath;
    } catch (e) {
      print('⚠️ Error creando ZIP: $e');
      rethrow;
    }
  }

  /// Crear ZIP del proyecto directamente en memoria (sin guardar localmente)
  /// [projectPath] - Ruta del proyecto (si es null, intenta usar la ruta predeterminada)
  /// Si la ruta predeterminada falla por permisos, lanza excepción para que el usuario seleccione el directorio
  /// Retorna los bytes del ZIP y el nombre del archivo
  Future<Map<String, dynamic>> createProjectZipInMemory({
    String? projectPath,
  }) async {
    try {
      // Determinar la ruta del proyecto
      final actualProjectPath =
          projectPath ??
          '/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform';
      final projectDir = Directory(actualProjectPath);

      if (!await projectDir.exists()) {
        throw Exception(
          'El directorio del proyecto no existe: $actualProjectPath',
        );
      }

      print('📦 Creando ZIP del proyecto en memoria...');
      print('   Origen: $actualProjectPath');

      final archive = Archive();
      int filesAdded = 0;
      int totalSize = 0;

      // Añadir todos los archivos del proyecto al ZIP
      await for (final entity in projectDir.list(recursive: true)) {
        final entityName = path.basename(entity.path);

        // Omitir directorios excluidos
        if (entity is Directory && _shouldExcludeDirectory(entityName)) {
          continue;
        }

        // Omitir archivos excluidos
        if (entity is File && _shouldExcludeFile(entityName)) {
          continue;
        }

        if (entity is File) {
          try {
            final relativePath = path.relative(
              entity.path,
              from: actualProjectPath,
            );
            final fileBytes = await entity.readAsBytes();
            final archiveFile = ArchiveFile(
              relativePath,
              fileBytes.length,
              fileBytes,
            );
            archive.addFile(archiveFile);
            totalSize += fileBytes.length;
            filesAdded++;

            if (filesAdded % 100 == 0) {
              print('   📄 Archivos añadidos: $filesAdded...');
            }
          } catch (e) {
            print('   ⚠️  Error añadiendo ${entity.path}: $e');
            // Continuar con el siguiente archivo
          }
        }
      }

      print('   ✅ Archivos añadidos al ZIP: $filesAdded');
      print(
        '   Tamaño total: ${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      // Crear el ZIP en memoria
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) {
        throw Exception('Error al crear el archivo ZIP');
      }

      // Generar nombre del archivo
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'project_backup_$timestamp.zip';

      print('✅ ZIP creado en memoria: $fileName');
      print(
        '   Tamaño del ZIP: ${(zipBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      return {
        'bytes': zipBytes,
        'fileName': fileName,
        'filesCount': filesAdded,
        'sizeBytes': totalSize,
      };
    } catch (e) {
      print('❌ Error creando ZIP en memoria: $e');
      rethrow;
    }
  }

  /// Eliminar un backup del proyecto
  Future<void> deleteProjectBackup(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        print('✅ Backup eliminado: $backupPath');
      }

      // También eliminar el ZIP si existe
      final zipFile = File('$backupPath.zip');
      if (await zipFile.exists()) {
        await zipFile.delete();
        print('✅ ZIP eliminado: $backupPath.zip');
      }

      if (!await backupDir.exists() && !await zipFile.exists()) {
        throw Exception('El directorio de backup no existe: $backupPath');
      }
    } catch (e) {
      print('❌ Error eliminando backup: $e');
      rethrow;
    }
  }

  /// Obtener la ruta base de backups
  String get backupBasePath => _backupBasePath;
}
