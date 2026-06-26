import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
  static String get apiBaseUrl {
    final url = getEnvVariable('API_BASE_URL');

    if (kIsWeb) {
      final pageHost = Uri.base.host;
      final isLocal =
          pageHost == 'localhost' || pageHost == '127.0.0.1' || pageHost == '';

      if (!isLocal) {
        // Acceso remoto (ej: Tailscale, producción).
        // La API está expuesta en la misma origin via proxy inverso
        // (Tailscale Serve enruta /api/* → puerto 8089, Caddy en Docker, etc.).
        // Usar misma origin evita mixed-content y no necesita CORS.
        return Uri.base.origin; // ej: https://mac-studio.tail9e7bd.ts.net:8443
      }

      // Acceso local: usar API_BASE_URL del .env o fallback a localhost
      if (url.isNotEmpty) return url;
      if (kDebugMode) return 'http://localhost:8089';
      return url;
    }

    // No-web: usar API_BASE_URL del .env
    return url;
  }
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
