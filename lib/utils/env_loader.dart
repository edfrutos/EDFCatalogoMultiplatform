import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Mapa global para variables de entorno como respaldo
final Map<String, String> globalEnvMap = <String, String>{};

/// Función para cargar variables de entorno desde assets (Android/Web)
Future<bool> loadEnvFromAssets() async {
  try {
    print('🔍 Intentando cargar .env desde assets...');
    final String envString = await rootBundle.loadString('.env');
    print('✅ Asset .env cargado, longitud: ${envString.length} caracteres');

    // Parsear el contenido manualmente y cargar en el mapa global
    print('🔧 Parseando variables de entorno desde string...');
    final lines = envString.split('\n');
    int variablesLoaded = 0;

    // Limpiar el mapa global primero
    globalEnvMap.clear();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        final equalIndex = trimmed.indexOf('=');
        if (equalIndex != -1) {
          final key = trimmed.substring(0, equalIndex).trim();
          final value = trimmed.substring(equalIndex + 1).trim();

          // Limpiar comillas si existen
          final cleanValue = value
              .replaceAll(RegExp(r'^"'), '')
              .replaceAll(RegExp(r'"$'), '')
              .replaceAll(RegExp(r"^'"), '')
              .replaceAll(RegExp(r"'$"), '');

          globalEnvMap[key] = cleanValue;
          variablesLoaded++;
          print(
            '   ✅ $key = ${cleanValue.length > 50 ? "${cleanValue.substring(0, 50)}..." : cleanValue}',
          );
        }
      }
    }

    print('✅ Total de variables cargadas manualmente: $variablesLoaded');

    // Verificar algunas variables críticas
    print('📋 Verificando variables críticas:');
    print(
      '   MONGO_URI: ${globalEnvMap['MONGO_URI']?.isNotEmpty == true ? "✅" : "❌"}',
    );
    print(
      '   MONGO_DB: ${globalEnvMap['MONGO_DB']?.isNotEmpty == true ? "✅" : "❌"}',
    );

    return variablesLoaded > 0;
  } catch (e) {
    print('❌ Error cargando .env desde assets: $e');
    return false;
  }
}

/// Obtener una variable de entorno con respaldo al mapa global
String getEnvVariable(String key, {String defaultValue = ''}) {
  try {
    // Intentar obtener de dotenv primero
    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  } catch (e) {
    // Ignorar error y usar respaldo
  }

  // Usar mapa global como respaldo
  return globalEnvMap[key] ?? defaultValue;
}
