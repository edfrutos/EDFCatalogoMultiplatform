import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Mapa global de variables de entorno (fallback cuando dotenv no está disponible).
final Map<String, String> globalEnvMap = <String, String>{};

// ─────────────────────────────────────────────────────────────────────────────
// API pública
// ─────────────────────────────────────────────────────────────────────────────

/// Inicializa las variables de entorno según la plataforma.
///
/// Orden de prioridad:
///   Web / Android → asset Flutter (.env empaquetado en el bundle)
///   Linux         → rutas relativas al ejecutable, luego búsqueda genérica
///   macOS / iOS   → bundle de la app, luego búsqueda genérica
///   Windows       → búsqueda genérica
///
/// Devuelve `true` si se cargó al menos una variable.
Future<bool> initEnv() async {
  if (kIsWeb) {
    return _loadFromAssets();
  }

  if (Platform.isAndroid) {
    return _loadFromAssets();
  }

  // Plataformas desktop: buscar archivo físico
  if (Platform.isLinux) {
    if (await _loadFromLinuxBundle()) return true;
  }

  if (Platform.isMacOS || Platform.isIOS) {
    if (await _loadFromAppleBundle()) return true;
  }

  return _loadFromSearchPaths();
}

/// Obtiene una variable de entorno con fallback al mapa global.
///
/// Orden: dotenv → globalEnvMap → [defaultValue]
String getEnvVariable(String key, {String defaultValue = ''}) {
  try {
    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) return value;
    }
  } catch (_) {}
  return globalEnvMap[key] ?? defaultValue;
}

/// Carga variables de entorno desde un asset Flutter (Web / Android).
///
/// Expuesta para uso directo en tests o casos especiales.
Future<bool> loadEnvFromAssets() => _loadFromAssets();

// ─────────────────────────────────────────────────────────────────────────────
// Implementación interna
// ─────────────────────────────────────────────────────────────────────────────

/// Parsea una línea de .env.
/// Devuelve null si la línea es un comentario, vacía o malformada.
MapEntry<String, String>? _parseLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) return null;

  final eqIndex = trimmed.indexOf('=');
  if (eqIndex == -1) return null;

  final key = trimmed.substring(0, eqIndex).trim();
  if (key.isEmpty) return null;

  final raw = trimmed.substring(eqIndex + 1).trim();
  final value = raw
      .replaceAll(RegExp(r'^"'), '')
      .replaceAll(RegExp(r'"$'), '')
      .replaceAll(RegExp(r"^'"), '')
      .replaceAll(RegExp(r"'$"), '');

  return MapEntry(key, value);
}

/// Parsea el contenido completo de un .env y rellena [globalEnvMap] y dotenv.
///
/// Escribe en AMBOS para garantizar coherencia independientemente
/// de qué mecanismo use el resto del código.
int _parseContent(String content) {
  globalEnvMap.clear();
  int count = 0;
  for (final line in content.split('\n')) {
    final entry = _parseLine(line);
    if (entry != null) {
      globalEnvMap[entry.key] = entry.value;
      try {
        dotenv.env[entry.key] = entry.value;
      } catch (_) {}
      count++;
    }
  }
  return count;
}

/// Intenta cargar el .env desde un archivo físico.
/// Primero prueba dotenv.load(); si falla, hace lectura manual.
Future<bool> _tryLoadFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) return false;

  try {
    await dotenv.load(fileName: path);
    // dotenv.load() no rellena globalEnvMap — sincronizamos
    for (final entry in dotenv.env.entries) {
      globalEnvMap[entry.key] = entry.value;
    }
    return globalEnvMap.isNotEmpty;
  } catch (_) {}

  // Fallback: lectura manual
  try {
    final content = await file.readAsString();
    return _parseContent(content) > 0;
  } catch (_) {
    return false;
  }
}

// ── Carga por plataforma ──────────────────────────────────────────────────────

Future<bool> _loadFromAssets() async {
  try {
    final content = await rootBundle.loadString('.env');
    return _parseContent(content) > 0;
  } catch (_) {
    return false;
  }
}

Future<bool> _loadFromLinuxBundle() async {
  try {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final candidates = [
      '${executableDir.path}/.env',
      '${executableDir.path}/data/.env',
      '${executableDir.parent.path}/.env',
      '${executableDir.parent.parent.path}/.env',
    ];
    for (final path in candidates) {
      if (await _tryLoadFile(path)) return true;
    }
  } catch (_) {}
  return false;
}

Future<bool> _loadFromAppleBundle() async {
  try {
    final executablePath = Platform.resolvedExecutable;
    final String envPath;
    if (Platform.isIOS) {
      // ejecutable → bundle.app
      envPath = '${File(executablePath).parent.parent.path}/.env';
    } else {
      // MacOS/ejecutable → Contents/MacOS → Contents
      envPath = '${File(executablePath).parent.parent.path}/Resources/.env';
    }
    return await _tryLoadFile(envPath);
  } catch (_) {
    return false;
  }
}

Future<bool> _loadFromSearchPaths() async {
  final paths = <String>[];

  // 1. Buscar raíz del proyecto subiendo desde el cwd (útil con flutter run)
  try {
    var dir = Directory.current;
    for (int i = 0; i < 15; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        paths.insert(0, '${dir.path}/.env');
        break;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // 2. Rutas conocidas según HOME
  try {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      paths.addAll([
        '$home/Proyectos/EDFCatalogoMultiplatform/.env',
        '$home/Projects/EDFCatalogoMultiplatform/.env',
      ]);
    }
  } catch (_) {}

  // 3. Relativas al ejecutable (subiendo niveles)
  if (!kIsWeb) {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 6; i++) {
        paths.add('${dir.path}/.env');
        dir = dir.parent;
      }
    } catch (_) {}
  }

  // 4. Relativas al cwd
  paths.addAll(['.env', '../.env', '../../.env']);

  for (final path in paths.toSet()) {
    if (await _tryLoadFile(path)) return true;
  }
  return false;
}
