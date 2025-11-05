#!/usr/bin/env dart
// Script para limpiar catálogos duplicados en MongoDB
// Uso: dart run scripts/cleanup_duplicate_catalogs.dart
//      (desde la raíz del proyecto)

import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

Future<void> _loadEnvFile(File file, Map<String, String> envVars) async {
  final lines = await file.readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index > 0) {
      final key = trimmed.substring(0, index).trim();
      var value = trimmed.substring(index + 1).trim();
      // Remover comillas si existen
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      envVars[key] = value;
    }
  }
}

Future<void> main() async {
  print('🔍 Iniciando limpieza de catálogos duplicados...\n');

  // Cargar configuración de entorno
  final envVars = <String, String>{};
  try {
    // Buscar .env en el directorio actual o en el directorio del script
    final currentDir = Directory.current.path;
    final scriptDir = Directory(Platform.script.toFilePath()).parent.path;

    File? envFile;
    final possiblePaths = [
      File('.env'), // Directorio actual
      File('$currentDir/.env'), // Directorio actual (absoluto)
      File('$scriptDir/../.env'), // Un nivel arriba del script
      File('${scriptDir.replaceAll('/scripts', '')}/.env'), // Raíz del proyecto
    ];

    for (final path in possiblePaths) {
      if (path.existsSync()) {
        envFile = path;
        break;
      }
    }

    if (envFile == null) {
      print('❌ No se encontró el archivo .env');
      print('   Buscado en:');
      for (final path in possiblePaths) {
        print('     - ${path.path}');
      }
      exit(1);
    }

    await _loadEnvFile(envFile, envVars);
    print('✅ Archivo .env cargado desde: ${envFile.path}\n');
  } catch (e) {
    print('⚠️ Error cargando .env: $e');
    exit(1);
  }

  // Conectar a MongoDB
  final mongoUri = envVars['MONGO_URI'] ?? '';
  final dbName = envVars['MONGO_DB'] ?? '';

  if (mongoUri.isEmpty || dbName.isEmpty) {
    print('❌ Error: MONGO_URI o MONGO_DB no están configurados en .env');
    exit(1);
  }

  Db? db;
  try {
    // Crear la conexión a MongoDB
    // La URI puede tener parámetros de consulta (?retryWrites=true&w=majority...)
    // Necesitamos insertar el nombre de la base de datos antes de los parámetros
    String uriToUse;

    if (mongoUri.contains('?') || mongoUri.contains('&')) {
      // La URI tiene parámetros de consulta
      final uriParts = mongoUri.split('?');
      final baseUri = uriParts[0];
      final queryParams = uriParts.length > 1 ? '?${uriParts[1]}' : '';

      // Verificar si la base de datos ya está en la URI
      if (baseUri.endsWith('/$dbName') || baseUri.endsWith('/$dbName/')) {
        uriToUse = mongoUri;
      } else if (baseUri.endsWith('/')) {
        uriToUse = '$baseUri$dbName$queryParams';
      } else {
        uriToUse = '$baseUri/$dbName$queryParams';
      }
    } else {
      // La URI no tiene parámetros de consulta
      if (mongoUri.endsWith('/$dbName') || mongoUri.endsWith('/$dbName/')) {
        uriToUse = mongoUri;
      } else if (mongoUri.endsWith('/')) {
        uriToUse = '$mongoUri$dbName';
      } else {
        uriToUse = '$mongoUri/$dbName';
      }
    }

    print(
      '🔗 URI de conexión: ${uriToUse.replaceAll(RegExp(r'://[^@]+@'), '://***@')}',
    );
    db = await Db.create(uriToUse);
    await db.open();
    print('✅ Conectado a MongoDB: ${db.databaseName}\n');

    // Verificar que estamos en la base de datos correcta
    if (db.databaseName != dbName) {
      print(
        '⚠️ Advertencia: Base de datos conectada (${db.databaseName}) no coincide con la configurada ($dbName)',
      );
      print('   Intentando usar la base de datos correcta...');
      await db.close();
      // Reintentar con la construcción correcta
      final uriParts = mongoUri.split('?');
      final baseUri = uriParts[0].replaceAll(RegExp(r'/[^/]+$'), '');
      final queryParams = uriParts.length > 1 ? '?${uriParts[1]}' : '';
      uriToUse = '$baseUri/$dbName$queryParams';
      print(
        '🔗 URI corregida: ${uriToUse.replaceAll(RegExp(r'://[^@]+@'), '://***@')}',
      );
      db = await Db.create(uriToUse);
      await db.open();
      print('✅ Reconectado a MongoDB: ${db.databaseName}\n');
    }

    final collection = db.collection('catalogs');

    // Obtener todos los catálogos
    final allCatalogs = await collection.find().toList();
    print('📊 Total de catálogos encontrados: ${allCatalogs.length}\n');

    // Agrupar por nombre y propietario
    final Map<String, List<Map<String, dynamic>>> groupedCatalogs = {};

    for (final catalog in allCatalogs) {
      // Buscar nombre en diferentes formatos (mayúsculas/minúsculas)
      final name = (catalog['Name'] ?? catalog['name'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      // Buscar propietario en diferentes formatos
      final owner =
          (catalog['Owner'] ??
                  catalog['CreatedBy'] ??
                  catalog['userId'] ??
                  catalog['UserId'] ??
                  '')
              .toString()
              .trim();

      if (name.isNotEmpty && owner.isNotEmpty) {
        final key = '$name|$owner';
        if (!groupedCatalogs.containsKey(key)) {
          groupedCatalogs[key] = [];
        }
        groupedCatalogs[key]!.add(catalog);
      }
    }

    print('📊 Grupos de catálogos encontrados: ${groupedCatalogs.length}\n');

    int duplicatesFound = 0;
    int duplicatesRemoved = 0;
    int catalogsUpdated = 0;
    final List<String> errors = [];

    // Procesar cada grupo
    for (final entry in groupedCatalogs.entries) {
      final catalogs = entry.value;

      if (catalogs.length <= 1) {
        continue; // No hay duplicados
      }

      duplicatesFound++;
      final catalogName =
          catalogs.first['Name'] ?? catalogs.first['name'] ?? 'Unknown';
      print(
        '🔍 Duplicados encontrados para: "$catalogName" (${catalogs.length} registros)',
      );

      // Encontrar el catálogo más completo (con más FileTitles)
      Map<String, dynamic>? bestCatalog;
      int maxFileTitles = -1;

      for (final catalog in catalogs) {
        int fileTitlesCount = 0;

        // Contar FileTitles en todas las filas
        final rows = catalog['Rows'] ?? catalog['rows'] ?? [];
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              final files = row['Files'] ?? row['files'] ?? {};
              if (files is Map) {
                final fileTitles =
                    files['FileTitles'] ?? files['fileTitles'] ?? {};
                if (fileTitles is Map) {
                  fileTitlesCount += fileTitles.length;
                }
              }
            }
          }
        }

        // También verificar UpdatedAt para determinar cuál es más reciente
        DateTime? updatedAt;
        try {
          final updatedAtStr = catalog['UpdatedAt'] ?? catalog['updatedAt'];
          if (updatedAtStr != null) {
            if (updatedAtStr is DateTime) {
              updatedAt = updatedAtStr;
            } else if (updatedAtStr is String) {
              updatedAt = DateTime.tryParse(updatedAtStr);
            } else if (updatedAtStr is Map && updatedAtStr['\$date'] != null) {
              updatedAt = DateTime.tryParse(updatedAtStr['\$date'].toString());
            }
          }
        } catch (e) {
          print('   ⚠️ Error parseando fecha: $e');
        }

        // Preferir el catálogo con más FileTitles, o si tienen los mismos, el más reciente
        if (fileTitlesCount > maxFileTitles ||
            (fileTitlesCount == maxFileTitles &&
                bestCatalog != null &&
                updatedAt != null)) {
          bool shouldReplace = false;
          if (fileTitlesCount > maxFileTitles) {
            shouldReplace = true;
          } else if (updatedAt != null && bestCatalog != null) {
            final bestUpdatedAt =
                bestCatalog['UpdatedAt'] ?? bestCatalog['updatedAt'];
            DateTime? bestUpdatedAtDate;
            try {
              if (bestUpdatedAt is DateTime) {
                bestUpdatedAtDate = bestUpdatedAt;
              } else if (bestUpdatedAt is String) {
                bestUpdatedAtDate = DateTime.tryParse(bestUpdatedAt);
              } else if (bestUpdatedAt is Map &&
                  bestUpdatedAt['\$date'] != null) {
                bestUpdatedAtDate = DateTime.tryParse(
                  bestUpdatedAt['\$date'].toString(),
                );
              }
            } catch (e) {
              // Ignorar errores de parsing
            }

            if (bestUpdatedAtDate == null ||
                updatedAt.isAfter(bestUpdatedAtDate)) {
              shouldReplace = true;
            }
          }

          if (shouldReplace) {
            bestCatalog = catalog;
            maxFileTitles = fileTitlesCount;
          }
        }
      }

      if (bestCatalog == null) {
        print('   ⚠️ No se pudo determinar el mejor catálogo, saltando...\n');
        continue;
      }

      final bestId = bestCatalog['_id'].toString();
      print(
        '   ✅ Mejor catálogo seleccionado: $bestId ($maxFileTitles FileTitles)',
      );

      // Verificar si el mejor catálogo tiene el formato correcto (mayúsculas)
      final needsUpdate =
          bestCatalog.containsKey('name') ||
          bestCatalog.containsKey('fileTitles');
      if (needsUpdate) {
        print('   🔄 El catálogo mejor necesita actualización de formato...');
        // Aquí podrías actualizar el formato si es necesario
      }

      // Eliminar los duplicados (excepto el mejor)
      for (final catalog in catalogs) {
        final catalogId = catalog['_id'].toString();
        if (catalogId != bestId) {
          try {
            ObjectId? objectId;
            try {
              objectId = ObjectId.fromHexString(catalogId);
            } catch (_) {
              // Si no es ObjectId, intentar eliminar directamente
              final result = await collection.deleteOne(
                where.eq('_id', catalogId),
              );
              if (result.isSuccess) {
                duplicatesRemoved++;
                print('   🗑️  Eliminado duplicado: $catalogId');
              } else {
                errors.add('Error eliminando $catalogId');
                print('   ❌ Error eliminando: $catalogId');
              }
              continue;
            }

            final result = await collection.deleteOne(where.id(objectId));
            if (result.isSuccess) {
              duplicatesRemoved++;
              print('   🗑️  Eliminado duplicado: $catalogId');
            } else {
              errors.add('Error eliminando $catalogId');
              print('   ❌ Error eliminando: $catalogId');
            }
          } catch (e) {
            errors.add('Error eliminando $catalogId: $e');
            print('   ❌ Error eliminando $catalogId: $e');
          }
        }
      }

      print('');
    }

    // Resumen
    print('\n${'=' * 60}');
    print('📊 RESUMEN DE LIMPIEZA');
    print('=' * 60);
    print('Grupos de duplicados encontrados: $duplicatesFound');
    print('Catálogos duplicados eliminados: $duplicatesRemoved');
    print('Catálogos actualizados: $catalogsUpdated');
    print('Errores: ${errors.length}');

    if (errors.isNotEmpty) {
      print('\n⚠️ Errores encontrados:');
      for (final error in errors) {
        print('   - $error');
      }
    }

    print('\n✅ Limpieza completada');

    await db.close();
  } catch (e) {
    print('❌ Error: $e');
    if (db != null) {
      await db.close();
    }
    exit(1);
  }
}
