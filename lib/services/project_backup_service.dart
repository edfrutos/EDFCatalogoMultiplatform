import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  static final String _backupBasePath = _resolveBackupBasePath();
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
    // ── macOS sandbox: directorios de caché y sistema ────────────────────────
    // Estos directorios pueden contener GBs de datos de caché (imágenes,
    // WebKit, HTTP, etc.) que no son parte de los datos de la app.
    'Caches',
    'HTTPStorages',
    'WebKit',
    'Logs',
    'TemporaryItems',
    'CachedData',
    'CloudDocs',
    'com.apple.nsurlsessiond',
    // ─────────────────────────────────────────────────────────────────────────
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

  /// Descargar un archivo de backup
  Future<String> downloadBackup(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('El archivo no existe: $filePath');
      }

      // En iOS, usar el directorio de documentos de la aplicación
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/$fileName';

      // Copiar el archivo al directorio de documentos
      await file.copy(savePath);

      print('✅ Archivo descargado a: $savePath');

      // Devolver la ruta donde se guardó el archivo
      return savePath;
    } catch (e) {
      print('❌ Error al descargar el archivo: $e');
      rethrow;
    }
  }

  /// Verificar si un directorio debe ser excluido
  /// [dirName] - Nombre del directorio (basename)
  /// [fullPath] - Ruta completa del directorio (opcional, para verificar rutas completas)
  bool _shouldExcludeDirectory(String dirName, [String? fullPath]) {
    // Primero verificar por nombre
    if (_excludedDirs.contains(dirName)) {
      return true;
    }

    // Si se proporciona la ruta completa, verificar si contiene alguna ruta excluida
    if (fullPath != null) {
      final normalizedPath = path.normalize(fullPath);
      for (final excludedDir in _excludedDirs) {
        // Verificar si la ruta contiene el directorio excluido
        if (normalizedPath.contains(excludedDir)) {
          return true;
        }
      }
    }

    return false;
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
      final actualProjectPath = projectPath ?? _resolveDefaultProjectPath();
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
        if (entity is Directory &&
            _shouldExcludeDirectory(entityName, entity.path)) {
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
        if (entity is Directory &&
            _shouldExcludeDirectory(entityName, entity.path)) {
          continue;
        }

        // Verificar si el archivo debe ser excluido
        if (entity is File && _shouldExcludeFile(entityName)) {
          continue;
        }

        // Verificar si la ruta completa contiene algún directorio excluido
        if (entity is File && _shouldExcludeDirectory('', entity.path)) {
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

  /// Crear ZIP de los datos de la app directamente en memoria (sin guardar localmente).
  ///
  /// En macOS el sandbox container puede contener GBs de caché de imágenes
  /// (CachedNetworkImage → Library/Caches/). Este método evita ese problema
  /// haciendo backup SOLO de los directorios de datos relevantes de la app:
  ///   • getApplicationSupportDirectory() — datos persistentes de la app
  ///   • getApplicationDocumentsDirectory() — archivos del usuario (JSON exports, etc.)
  ///
  /// Si se pasa [projectPath] explícitamente, se usa ese directorio con los
  /// filtros habituales de exclusión (Caches, WebKit, HTTPStorages, etc.).
  Future<Map<String, dynamic>> createProjectZipInMemory({
    String? projectPath,
  }) async {
    try {
      final bool isIOS = Platform.isIOS;
      final bool isMacOS = !isIOS && Platform.isMacOS;

      final archive = Archive();
      int filesAdded = 0;
      int totalSize = 0;

      if (isIOS) {
        // iOS: solo archivos de base de datos en el directorio de documentos
        print('📱 Modo iOS: Incluyendo solo archivos de la aplicación...');
        final appDocDir = await getApplicationDocumentsDirectory();
        print('   Origen: ${appDocDir.path}');

        final dbFiles = await _findDatabaseFiles(appDocDir);
        print('🔍 Encontrados ${dbFiles.length} archivos de base de datos');

        for (final file in dbFiles) {
          try {
            final fileBytes = await file.readAsBytes();
            final relativePath = path.relative(file.path, from: appDocDir.path);
            archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
            totalSize += fileBytes.length;
            filesAdded++;
            print('   ✅ Añadido: $relativePath (${fileBytes.length} bytes)');
          } catch (e) {
            print('   ⚠️  Error añadiendo ${file.path}: $e');
          }
        }

        if (dbFiles.isEmpty) {
          print('ℹ️  No se encontraron archivos de base de datos para respaldar');
        }
      } else if (isMacOS && projectPath == null) {
        // macOS sin ruta explícita: backup de los datos relevantes de la app
        // (NO el container completo, que incluye Library/Caches con GBs de imágenes)
        final appSupportDir = await getApplicationSupportDirectory();
        final appDocDir = await getApplicationDocumentsDirectory();

        final directoriesToBackup = [
          MapEntry('AppSupport', appSupportDir),
          MapEntry('Documents', appDocDir),
        ];

        print('📦 Creando ZIP de datos de la app en macOS...');

        for (final entry in directoriesToBackup) {
          final label = entry.key;
          final dir = entry.value;

          if (!await dir.exists()) continue;
          print('   Incluyendo $label: ${dir.path}');

          final result = await _addFilesToArchiveRecursive(
            dir,
            dir.path,
            archive,
            pathPrefix: '$label/',
          );
          filesAdded += result['filesAdded'] as int;
          totalSize += result['totalSize'] as int;
        }
      } else {
        // Ruta explícita o plataforma no-macOS: lógica normal con filtros de exclusión
        final actualProjectPath = projectPath ?? _resolveDefaultProjectPath();
        final projectDir = Directory(actualProjectPath);

        if (!await projectDir.exists()) {
          throw Exception('El directorio no existe: $actualProjectPath');
        }

        print('📦 Creando ZIP del proyecto en memoria...');
        print('   Origen: $actualProjectPath');

        final result = await _addFilesToArchiveRecursive(
          projectDir,
          actualProjectPath,
          archive,
        );
        filesAdded = result['filesAdded'] as int;
        totalSize = result['totalSize'] as int;
      }

      if (filesAdded == 0) {
        throw Exception('No se encontraron archivos para respaldar');
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
      final fileName = 'catalogo_backup_$timestamp.zip';

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

  /// Añadir archivos al archivo ZIP de forma recursiva, manejando errores de permisos.
  /// [pathPrefix] — prefijo opcional para las rutas dentro del ZIP.
  /// Retorna un mapa con 'filesAdded' y 'totalSize'
  Future<Map<String, int>> _addFilesToArchiveRecursive(
    dynamic dir,
    String projectRoot,
    Archive archive, {
    String pathPrefix = '',
  }) async {
    int filesAdded = 0;
    int totalSize = 0;

    try {
      // Intentar listar el directorio
      await for (final entity in dir.list()) {
        try {
          final entityName = path.basename(entity.path);
          final relativePath =
              pathPrefix + path.relative(entity.path, from: projectRoot);

          // Verificar si el directorio debe ser excluido usando la ruta completa
          if (entity is Directory) {
            if (_shouldExcludeDirectory(entityName, entity.path)) {
              continue;
            }

            // Recursivamente añadir archivos del subdirectorio
            final subResult = await _addFilesToArchiveRecursive(
              entity,
              projectRoot,
              archive,
              pathPrefix: pathPrefix,
            );
            filesAdded += subResult['filesAdded'] as int;
            totalSize += subResult['totalSize'] as int;
          } else if (entity is File) {
            // Verificar si el archivo debe ser excluido
            if (_shouldExcludeFile(entityName)) {
              continue;
            }

            // Verificar si la ruta completa contiene algún directorio excluido
            if (_shouldExcludeDirectory('', entity.path)) {
              continue;
            }

            try {
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
        } catch (e) {
          // Si hay un error con una entidad específica, continuar
          // (puede ser un problema de permisos en un subdirectorio específico)
          if (e.toString().contains('Operation not permitted') ||
              e.toString().contains('permission') ||
              e.toString().contains('PathAccessException')) {
            print(
              '   ⚠️  No se puede acceder a ${entity.path}: $e (continuando...)',
            );
            continue;
          }
          // Re-lanzar otros errores
          rethrow;
        }
      }
    } catch (e) {
      // Si falla al listar el directorio, verificar si es por permisos
      if (e.toString().contains('Operation not permitted') ||
          e.toString().contains('permission') ||
          e.toString().contains('PathAccessException')) {
        // Si es el directorio raíz, lanzar excepción
        if (path.normalize(dir.path) == path.normalize(projectRoot)) {
          throw Exception(
            'No se puede acceder al directorio del proyecto por falta de permisos.\n'
            'Por favor, selecciona el directorio del proyecto para otorgar permisos de lectura.\n'
            'Error: $e',
          );
        }
        // Si es un subdirectorio, solo continuar (no es crítico)
        print(
          '   ⚠️  No se puede acceder al directorio ${dir.path}: $e (omitido)',
        );
      } else {
        rethrow;
      }
    }

    return {'filesAdded': filesAdded, 'totalSize': totalSize};
  }

  /// Obtener la ruta base de backups
  String get backupBasePath => _backupBasePath;

  // ==== Helpers de rutas ====

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

  // Función para encontrar archivos de base de datos en un directorio
  Future<List<File>> _findDatabaseFiles(dynamic directory) async {
    final List<File> dbFiles = [];
    try {
      if (await directory.exists()) {
        final contents = directory.listSync(recursive: true);
        for (var entity in contents) {
          if (entity is File) {
            final ext = path.extension(entity.path).toLowerCase();
            // Incluir archivos de base de datos comunes
            if (ext == '.db' ||
                ext == '.sqlite' ||
                ext == '.sqlite3' ||
                entity.path.toLowerCase().contains('catalogo') ||
                entity.path.toLowerCase().contains('backup')) {
              dbFiles.add(entity);
            }
          }
        }
      }
    } catch (e) {
      print('⚠️  Error buscando archivos de base de datos: $e');
    }
    return dbFiles;
  }

  static String _resolveDefaultProjectPath() {
    // Primero intentar con el directorio actual del proyecto
    final currentDir = Directory.current.path;
    if (Directory(currentDir).existsSync()) {
      return path.normalize(currentDir);
    }

    // Luego intentar con variables de entorno
    final override = _readEnvOverrides(
      keys: const ['EDF_PROJECT_DIR', 'PROJECT_DIR'],
    );
    if (override != null && override.isNotEmpty) {
      final normalized = path.normalize(override);
      if (Directory(normalized).existsSync()) {
        return normalized;
      }
    }

    // Intentar detectar la raíz del proyecto
    final detectedRoot = _discoverProjectRoot();
    if (detectedRoot != null) {
      return detectedRoot;
    }

    // Último recurso: rutas comunes
    final homeDir = Platform.environment['HOME'];
    if (homeDir != null && homeDir.isNotEmpty) {
      final candidates = [
        path.join(homeDir, 'EDFCatalogoMultiplatform'),
        path.join(homeDir, 'proyectos', 'EDFCatalogoMultiplatform'),
        path.join(homeDir, '__Proyectos', 'EDFCatalogoMultiplatform'),
      ];

      for (final candidate in candidates) {
        if (Directory(candidate).existsSync()) {
          return path.normalize(candidate);
        }
      }
    }

    // Si todo falla, lanzar excepción en lugar de devolver '/'
    throw Exception(
      'No se pudo determinar la ruta del proyecto. Por favor, selecciona manualmente el directorio del proyecto.'
    );
  }

  static String? _discoverProjectRoot() {
    try {
      var currentDir = Directory(Directory.current.path);
      for (var i = 0; i < 20; i++) {
        final pubspec = File(path.join(currentDir.path, 'pubspec.yaml'));
        if (pubspec.existsSync()) {
          return path.normalize(currentDir.path);
        }
        final parent = currentDir.parent;
        if (parent.path == currentDir.path) {
          break;
        }
        currentDir = parent;
      }
    } catch (_) {
      // Ignorar errores y continuar con otros métodos de detección.
    }
    return null;
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
