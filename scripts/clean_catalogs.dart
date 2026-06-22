#!/usr/bin/env dart
// scripts/clean_catalogs.dart
//
// Elimina TODOS los documentos de la colección de catálogos en MongoDB.
// Uso: dart scripts/clean_catalogs.dart [--dry-run] [--help]
//
// Variables de entorno (una obligatoria):
//   MONGO_URI o MONGODB_URI              URI de conexión (no commitear credenciales)
//   MONGO_DB  o MONGODB_DB               Nombre de BD (defecto: edf_catalogotablas)
//   MONGO_CATALOGS_COLLECTION o
//   CLEAN_CATALOGS_COLLECTION            Colección (defecto: catalogs)
//
// Ejemplo:
//   export MONGO_URI='mongodb+srv://user:pass@cluster.mongodb.net'
//   dart scripts/clean_catalogs.dart --dry-run

import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _firstEnv(List<String> names) {
  for (final name in names) {
    final v = Platform.environment[name];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

void _printHelp() {
  stdout.writeln('''
clean_catalogs — elimina TODOS los documentos de la colección de catálogos.

Variables de entorno (una obligatoria):
  MONGO_URI o MONGODB_URI                URI de MongoDB.
  MONGO_DB  o MONGODB_DB                 Nombre de BD (defecto: edf_catalogotablas).
  MONGO_CATALOGS_COLLECTION o
  CLEAN_CATALOGS_COLLECTION              Colección (defecto: catalogs).

Argumentos:
  --dry-run    Solo muestra el recuento; no elimina nada.
  --help       Muestra esta ayuda.

Ejemplo:
  export MONGO_URI='mongodb+srv://...'
  dart scripts/clean_catalogs.dart
  dart scripts/clean_catalogs.dart --dry-run
''');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  final dryRun = args.contains('--dry-run');

  // Conexión
  final uri = _firstEnv(['MONGO_URI', 'MONGODB_URI']);
  if (uri == null) {
    stderr.writeln(
      '❌  Define MONGO_URI o MONGODB_URI con la cadena de conexión.\n'
      '    No versiones credenciales en el código.',
    );
    exit(1);
  }

  final dbName =
      _firstEnv(['MONGO_DB', 'MONGODB_DB']) ?? 'edf_catalogotablas';
  final collectionName =
      _firstEnv(['MONGO_CATALOGS_COLLECTION', 'CLEAN_CATALOGS_COLLECTION']) ??
          'catalogs';

  stdout.writeln('🔌 Conectando a MongoDB...');
  stdout.writeln('   Base de datos : $dbName');
  stdout.writeln('   Colección     : $collectionName');
  if (dryRun) stdout.writeln('   Modo          : dry-run (sin cambios)');

  final db = Db('$uri/$dbName');
  try {
    await db.open();
    stdout.writeln('✅ Conexión establecida.');

    final collection = db.collection(collectionName);
    final countBefore = await collection.count();
    stdout.writeln('📊 Documentos en \'$collectionName\': $countBefore');

    if (countBefore == 0) {
      stdout.writeln('ℹ️  No hay documentos que eliminar.');
      await db.close();
      exit(0);
    }

    if (dryRun) {
      stdout.writeln('✅ Dry-run finalizado (sin cambios).');
      await db.close();
      exit(0);
    }

    stdout.writeln('🗑️  Eliminando todos los documentos...');
    final result = await collection.deleteMany(<String, dynamic>{});
    final deleted = result.nRemoved;
    stdout.writeln('✅ Documentos eliminados: $deleted');

    final countAfter = await collection.count();
    stdout.writeln('📊 Documentos restantes : $countAfter');

    if (countAfter == 0) {
      stdout.writeln('🎉 Colección vaciada correctamente.');
    } else {
      stderr.writeln(
        '⚠️  Advertencia: quedan $countAfter documentos. '
        'Revisa filtros o permisos.',
      );
    }

    await db.close();
  } catch (e) {
    stderr.writeln('❌ Error: $e');
    try {
      await db.close();
    } catch (_) {}
    exit(1);
  }
}
