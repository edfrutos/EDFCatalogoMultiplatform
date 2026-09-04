#!/usr/bin/env dart
// scripts/seed_test_data.dart
//
// Siembra datos de prueba en MongoDB: usuario admin + catálogos de ejemplo.
// Idempotente — no crea duplicados si ya existen.
//
// Variables de entorno:
//   MONGO_URI o MONGODB_URI   (obligatoria)
//   MONGO_DB  o MONGODB_DB    (defecto: edf_catalogotablas)
//   ADMIN_EMAIL               (defecto: admin@edf.test)
//   ADMIN_PASSWORD            (defecto: Admin1234!)
//
// Uso:
//   dart scripts/seed_test_data.dart [--help]

import 'dart:io';
import 'dart:math';
import 'package:edfcatalogo_crypto/password_hasher.dart';
import 'package:mongo_dart/mongo_dart.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _env(List<String> names) {
  for (final name in names) {
    final v = Platform.environment[name];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// Hash canónico (SHA-256 Base64), el mismo que app y API.
String _hashPassword(String password) => PasswordHasher.hash(password);

String _randomId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(12, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void _printHelp() {
  stdout.writeln('''
seed_test_data — siembra datos de prueba en MongoDB.

Crea (si no existen):
  · 1 usuario admin
  · 3 catálogos de ejemplo con filas

Variables de entorno:
  MONGO_URI o MONGODB_URI   URI de MongoDB (obligatoria).
  MONGO_DB  o MONGODB_DB   Nombre de BD (defecto: edf_catalogotablas).
  ADMIN_EMAIL              Email del admin (defecto: admin@edf.test).
  ADMIN_PASSWORD           Contraseña del admin (defecto: Admin1234!).

Uso:
  export MONGO_URI='mongodb+srv://...'
  dart scripts/seed_test_data.dart
''');
}

// ---------------------------------------------------------------------------
// Datos de ejemplo
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _sampleCatalogs(String ownerEmail) {
  final now = DateTime.now().toUtc().toIso8601String();
  return [
    {
      '_id': _randomId(),
      'Name': 'Catálogo de Películas',
      'Owner': ownerEmail,
      'Columns': ['Título', 'Director', 'Año', 'Género'],
      'Rows': [
        {
          'Data': {
            'Título': 'El Padrino',
            'Director': 'Francis Ford Coppola',
            'Año': '1972',
            'Género': 'Drama',
          },
          'Files': <dynamic>[],
        },
        {
          'Data': {
            'Título': 'Blade Runner',
            'Director': 'Ridley Scott',
            'Año': '1982',
            'Género': 'Ciencia ficción',
          },
          'Files': <dynamic>[],
        },
        {
          'Data': {
            'Título': 'Mulholland Drive',
            'Director': 'David Lynch',
            'Año': '2001',
            'Género': 'Misterio',
          },
          'Files': <dynamic>[],
        },
      ],
      'CreatedAt': now,
      'UpdatedAt': now,
      'isShared': false,
    },
    {
      '_id': _randomId(),
      'Name': 'Inventario de Libros',
      'Owner': ownerEmail,
      'Columns': ['Título', 'Autor', 'ISBN', 'Stock'],
      'Rows': [
        {
          'Data': {
            'Título': 'Clean Code',
            'Autor': 'Robert C. Martin',
            'ISBN': '978-0132350884',
            'Stock': '3',
          },
          'Files': <dynamic>[],
        },
        {
          'Data': {
            'Título': 'The Pragmatic Programmer',
            'Autor': 'Andrew Hunt',
            'ISBN': '978-0201616224',
            'Stock': '2',
          },
          'Files': <dynamic>[],
        },
      ],
      'CreatedAt': now,
      'UpdatedAt': now,
      'isShared': false,
    },
    {
      '_id': _randomId(),
      'Name': 'Contactos',
      'Owner': ownerEmail,
      'Columns': ['Nombre', 'Email', 'Teléfono', 'Empresa'],
      'Rows': [
        {
          'Data': {
            'Nombre': 'Ana García',
            'Email': 'ana@ejemplo.com',
            'Teléfono': '+34 600 000 001',
            'Empresa': 'Acme S.L.',
          },
          'Files': <dynamic>[],
        },
        {
          'Data': {
            'Nombre': 'Luis Martínez',
            'Email': 'luis@ejemplo.com',
            'Teléfono': '+34 600 000 002',
            'Empresa': 'Beta Corp.',
          },
          'Files': <dynamic>[],
        },
      ],
      'CreatedAt': now,
      'UpdatedAt': now,
      'isShared': false,
    },
  ];
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  final uri = _env(['MONGO_URI', 'MONGODB_URI']);
  if (uri == null) {
    stderr.writeln('❌  Define MONGO_URI o MONGODB_URI.');
    exit(1);
  }

  final dbName = _env(['MONGO_DB', 'MONGODB_DB']) ?? 'edf_catalogotablas';
  final adminEmail = _env(['ADMIN_EMAIL']) ?? 'admin@edf.test';
  final adminPassword = _env(['ADMIN_PASSWORD']) ?? 'Admin1234!';

  stdout.writeln('🌱 Seeder de datos de prueba');
  stdout.writeln('   BD       : $dbName');
  stdout.writeln('   Admin    : $adminEmail');

  final db = Db('$uri/$dbName');
  try {
    await db.open();
    stdout.writeln('✅ Conexión establecida.');

    // -----------------------------------------------------------------------
    // Usuario admin
    // -----------------------------------------------------------------------
    final users = db.collection('users');
    final existing = await users.findOne({'Email': adminEmail});

    if (existing != null) {
      stdout.writeln('ℹ️  Usuario admin ya existe ($adminEmail). Sin cambios.');
    } else {
      final now = DateTime.now().toUtc().toIso8601String();
      await users.insertOne({
        '_id': _randomId(),
        'Email': adminEmail,
        'Username': 'admin',
        'Password': _hashPassword(adminPassword),
        'Role': 'admin',
        'IsActive': true,
        'CreatedAt': now,
        'UpdatedAt': now,
      });
      stdout.writeln('👤 Usuario admin creado: $adminEmail');
    }

    // -----------------------------------------------------------------------
    // Catálogos de ejemplo
    // -----------------------------------------------------------------------
    final catalogs = db.collection('catalogs');
    final existingCount = await catalogs.count();

    if (existingCount > 0) {
      stdout.writeln(
        'ℹ️  Ya existen $existingCount catálogos. No se crean duplicados.',
      );
    } else {
      final samples = _sampleCatalogs(adminEmail);
      await catalogs.insertMany(samples);
      stdout.writeln('📁 Catálogos de ejemplo creados: ${samples.length}');

      int totalRows = 0;
      for (final c in samples) {
        totalRows += (c['Rows'] as List).length;
      }
      stdout.writeln('   Filas totales: $totalRows');
    }

    // -----------------------------------------------------------------------
    // Resumen
    // -----------------------------------------------------------------------
    stdout.writeln('');
    stdout.writeln('🎉 Seed completado:');
    stdout.writeln('   Usuarios   : ${await users.count()}');
    stdout.writeln('   Catálogos  : ${await catalogs.count()}');

    await db.close();
  } catch (e) {
    stderr.writeln('❌ Error: $e');
    try {
      await db.close();
    } catch (_) {}
    exit(1);
  }
}
