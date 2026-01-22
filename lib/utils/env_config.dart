import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'env_loader.dart';

/// Clase para gestionar las variables de entorno
class EnvConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // MongoDB
  static String get mongoUri {
    try {
      return getEnvVariable('MONGO_URI');
    } catch (e) {
      print('⚠️ Error accediendo a MONGO_URI: $e');
      return '';
    }
  }

  static String get mongoDb {
    try {
      return getEnvVariable('MONGO_DB');
    } catch (e) {
      print('⚠️ Error accediendo a MONGO_DB: $e');
      return '';
    }
  }

  // AWS S3
  static String get awsAccessKeyId => getEnvVariable('AWS_ACCESS_KEY_ID');
  static String get awsSecretAccessKey =>
      getEnvVariable('AWS_SECRET_ACCESS_KEY');
  static String get awsRegion =>
      getEnvVariable('AWS_REGION', defaultValue: 'eu-central-1');
  // Intentar ambos nombres: S3_BUCKET_NAME y BUCKET_NAME
  static String get bucketName {
    final s3Bucket = getEnvVariable('S3_BUCKET_NAME');
    return s3Bucket.isNotEmpty ? s3Bucket : getEnvVariable('BUCKET_NAME');
  }

  static bool get useS3 => getEnvVariable('USE_S3').toLowerCase() == 'true';

  // Email Service (Brevo)
  static String get brevoApiKey => getEnvVariable('BREVO_API_KEY');
  static String get brevoSmtpServer =>
      getEnvVariable('BREVO_SMTP_SERVER', defaultValue: 'smtp-relay.brevo.com');
  static int get brevoSmtpPort =>
      int.tryParse(getEnvVariable('BREVO_SMTP_PORT', defaultValue: '587')) ??
      587;

  // Google OAuth (opcional)
  static String get googleClientId => getEnvVariable('GOOGLE_CLIENT_ID');
  static String get googleClientSecret =>
      getEnvVariable('GOOGLE_CLIENT_SECRET');

  // Google Drive (para backups)
  static String get googleDriveFolder => getEnvVariable(
    'GOOGLE_DRIVE_FOLDER',
    defaultValue: 'Backups_CatalogoTablas',
  );
  static String get googleProjectId => getEnvVariable('GOOGLE_PROJECT_ID');
  static bool get useGoogleDrive {
    final useDriveEnv = getEnvVariable('USE_GOOGLE_DRIVE').toLowerCase();
    if (useDriveEnv.isNotEmpty) {
      return useDriveEnv == 'true';
    }
    // Si hay client ID y secret, asumir que se quiere usar Drive
    return googleClientId.isNotEmpty && googleClientSecret.isNotEmpty;
  }

  // Backend API (para Flutter Web)
  static String get apiBaseUrl => getEnvVariable('API_BASE_URL');
  static bool get useApiBackend => apiBaseUrl.isNotEmpty;

  /// Validar que las variables críticas estén configuradas
  static bool validate() {
    if (mongoUri.isEmpty || mongoDb.isEmpty) {
      return false;
    }
    if (useS3 && (awsAccessKeyId.isEmpty || awsSecretAccessKey.isEmpty)) {
      return false;
    }
    return true;
  }
}
