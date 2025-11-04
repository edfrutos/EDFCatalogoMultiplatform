/// Tipo de backup
enum BackupType { catalogs, users }

/// Información de un backup (compatible con Google Drive y Local)
class BackupInfo {
  final String name;
  final int size;
  final DateTime created;
  final BackupType type;
  final String?
  driveFileId; // ID del archivo en Google Drive (null para backups locales)
  final String?
  localFilePath; // Ruta del archivo local (null para backups de Google Drive)

  BackupInfo({
    required this.name,
    required this.size,
    required this.created,
    required this.type,
    this.driveFileId,
    this.localFilePath,
  });

  /// Crear BackupInfo desde LocalBackupInfo
  // factory BackupInfo.fromLocal(LocalBackupInfo local) {
  //   return BackupInfo(
  //     name: local.fileName,
  //     size: local.sizeBytes,
  //     created: local.createdAt,
  //     type: local.type,
  //     localFilePath: local.filePath,
  //   );
  // }

  String get fileName => name;

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedSize => sizeFormatted;

  String get formattedDate {
    return '${created.day}/${created.month}/${created.year} '
        '${created.hour}:${created.minute.toString().padLeft(2, '0')}';
  }

  bool get isLocal => localFilePath != null;
  bool get isGoogleDrive => driveFileId != null;
}

// Importar LocalBackupInfo para el factory
// Importar LocalBackupInfo para el factory (debe estar después de la definición)
// import '../services/local_backup_service.dart';
