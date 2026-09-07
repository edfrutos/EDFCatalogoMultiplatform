import 'package:equatable/equatable.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

/// Modelo de catálogo
class Catalog extends Equatable {
  final String id;
  final String name;
  final String description;
  final String userId;
  final List<String> columns;
  final List<CatalogRow> rows;
  final Map<String, dynamic>? legacyRows;
  final String? thumbnailUrl; // URL de la imagen del catálogo
  final DateTime createdAt;
  final DateTime updatedAt;

  const Catalog({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    required this.columns,
    this.rows = const [],
    this.legacyRows,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor para crear desde JSON (MongoDB)
  factory Catalog.fromJson(Map<String, dynamic> json) {
    try {
      // MongoDB usa mayúsculas, pero también puede venir en minúsculas
      final name = json['Name'] ?? json['name'] ?? 'Sin nombre';
      final description = json['Description'] ?? json['description'] ?? '';
      final owner = json['Owner'] ?? json['CreatedBy'] ?? json['userId'] ?? '';

      // Headers en MongoDB, columns en minúsculas
      List<String> columns = [];
      if (json['Headers'] != null) {
        columns =
            (json['Headers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      } else if (json['columns'] != null) {
        columns =
            (json['columns'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }

      // Rows en MongoDB (mayúscula), rows en minúsculas
      List<CatalogRow> rows = [];
      Map<String, CatalogRow> rowsMap = {}; // Para detectar duplicados por _id
      List<String> rowOrder = []; // Mantener orden de inserción

      void processRow(CatalogRow row) {
        final rowId = row.id;

        // Si ya existe una fila con el mismo ID, comparar y mantener la mejor
        if (rowsMap.containsKey(rowId)) {
          final existingRow = rowsMap[rowId]!;

          // Priorizar la fila que tiene archivos, o la más reciente (updatedAt)
          bool shouldReplace = false;

          if (!existingRow.files.hasAnyFiles && row.files.hasAnyFiles) {
            // La nueva tiene archivos y la existente no
            shouldReplace = true;
            print(
              '🔄 Reemplazando fila duplicada (ID: $rowId): la nueva tiene archivos',
            );
          } else if (existingRow.files.hasAnyFiles && !row.files.hasAnyFiles) {
            // La existente tiene archivos y la nueva no, mantener la existente
            print(
              '⏭️  Manteniendo fila existente (ID: $rowId): la existente tiene archivos',
            );
          } else {
            // Ambas tienen archivos o ninguna tiene, usar la más reciente
            if (row.updatedAt.isAfter(existingRow.updatedAt)) {
              shouldReplace = true;
              print(
                '🔄 Reemplazando fila duplicada (ID: $rowId): la nueva es más reciente',
              );
            }
          }

          if (shouldReplace) {
            rowsMap[rowId] = row;
          }
        } else {
          rowsMap[rowId] = row;
          rowOrder.add(rowId); // Mantener orden de inserción
        }
      }

      if (json['Rows'] != null) {
        final rowsList = json['Rows'] as List<dynamic>?;
        if (rowsList != null) {
          print(
            '📋 Catalog.fromJson - Parseando ${rowsList.length} filas desde MongoDB (Rows con mayúscula)',
          );
          for (final e in rowsList) {
            if (e is Map<String, dynamic>) {
              try {
                print(
                  '📋 Catalog.fromJson - Parseando fila, keys disponibles: ${e.keys.toList()}',
                );
                final row = CatalogRow.fromJson(e);
                if (row.files.fileTitles.isNotEmpty) {
                  print(
                    '📋 Catalog.fromJson - Fila parseada con ${row.files.fileTitles.length} títulos: ${row.files.fileTitles}',
                  );
                } else {
                  print('📋 Catalog.fromJson - Fila parseada sin títulos');
                }
                processRow(row);
              } catch (e) {
                print('⚠️ Error parseando fila: $e');
              }
            } else {
              print('⚠️ Fila no es un Map, es: ${e.runtimeType}');
            }
          }
          print(
            '📋 Catalog.fromJson - Total de filas únicas procesadas: ${rowsMap.length}',
          );
        }
      } else if (json['rows'] != null) {
        final rowsList = json['rows'] as List<dynamic>?;
        if (rowsList != null) {
          print(
            '📋 Catalog.fromJson - Parseando ${rowsList.length} filas desde MongoDB (rows con minúscula)',
          );
          for (final e in rowsList) {
            if (e is Map<String, dynamic>) {
              try {
                print(
                  '📋 Catalog.fromJson - Parseando fila, keys disponibles: ${e.keys.toList()}',
                );
                final row = CatalogRow.fromJson(e);
                if (row.files.fileTitles.isNotEmpty) {
                  print(
                    '📋 Catalog.fromJson - Fila parseada con ${row.files.fileTitles.length} títulos: ${row.files.fileTitles}',
                  );
                } else {
                  print('📋 Catalog.fromJson - Fila parseada sin títulos');
                }
                processRow(row);
              } catch (e) {
                print('⚠️ Error parseando fila: $e');
              }
            } else {
              print('⚠️ Fila no es un Map, es: ${e.runtimeType}');
            }
          }
          print(
            '📋 Catalog.fromJson - Total de filas únicas procesadas: ${rowsMap.length}',
          );
        }
      } else {
        print(
          '⚠️ Catalog.fromJson - No se encontraron filas (Rows/rows no presentes)',
        );
      }

      // Convertir el Map a lista, manteniendo el orden de inserción
      rows = rowOrder.map((id) => rowsMap[id]!).toList();

      // Helper para parsear fechas que pueden venir como DateTime, Map con $date, o String
      DateTime? parseDateTime(dynamic dateValue) {
        if (dateValue == null) return null;
        if (dateValue is DateTime) return dateValue;
        if (dateValue is Map && dateValue['\$date'] != null) {
          // Formato MongoDB: {"$date": "2025-10-12T18:47:09.424Z"}
          final dateStr = dateValue['\$date'].toString();
          return DateTime.tryParse(dateStr);
        }
        if (dateValue is String) {
          return DateTime.tryParse(dateValue);
        }
        return null;
      }

      DateTime createdAt =
          parseDateTime(json['CreatedAt']) ??
          parseDateTime(json['createdAt']) ??
          DateTime.now();

      DateTime updatedAt =
          parseDateTime(json['UpdatedAt']) ??
          parseDateTime(json['updatedAt']) ??
          DateTime.now();

      // Manejar _id: puede ser String, ObjectId, o Map con $oid
      String idValue = '';
      if (json['_id'] != null) {
        if (json['_id'] is String) {
          idValue = json['_id'] as String;
        } else if (json['_id'] is mongo.ObjectId) {
          // ObjectId en mongo_dart se convierte a String con .oid
          idValue = (json['_id'] as mongo.ObjectId).oid;
        } else if (json['_id'] is Map && json['_id']?['\$oid'] != null) {
          idValue = json['_id']?['\$oid'] ?? '';
        } else {
          idValue = json['_id'].toString();
        }
      } else {
        idValue = json['id']?.toString() ?? '';
      }

      // Parsear legacyRows - puede ser Map, List o null
      Map<String, dynamic>? legacyRowsValue;
      if (json['LegacyRows'] != null) {
        final legacyRowsData = json['LegacyRows'];
        if (legacyRowsData is Map<String, dynamic>) {
          legacyRowsValue = legacyRowsData;
        } else if (legacyRowsData is Map) {
          legacyRowsValue = legacyRowsData.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
        // Si es List, lo ignoramos (no es el formato esperado para legacyRows)
      } else if (json['legacyRows'] != null) {
        final legacyRowsData = json['legacyRows'];
        if (legacyRowsData is Map<String, dynamic>) {
          legacyRowsValue = legacyRowsData;
        } else if (legacyRowsData is Map) {
          legacyRowsValue = legacyRowsData.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
        // Si es List, lo ignoramos (no es el formato esperado para legacyRows)
      }

      // Parsear thumbnailUrl (Miniatura en MongoDB)
      final thumbnailUrl =
          json['ThumbnailUrl']?.toString() ??
          json['Miniatura']?.toString() ??
          json['Thumbnail']?.toString() ??
          json['thumbnailUrl']?.toString();

      return Catalog(
        id: idValue,
        name: name.toString(),
        description: description.toString(),
        userId: owner.toString(),
        columns: columns,
        rows: rows,
        legacyRows: legacyRowsValue,
        thumbnailUrl: thumbnailUrl?.isNotEmpty == true ? thumbnailUrl : null,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      print('❌ Error en Catalog.fromJson: $e');
      print('   Stack trace: $stackTrace');
      print('   JSON keys disponibles: ${json.keys.toList()}');
      // Mostrar más detalles del documento problemático
      print(
        '   Documento completo (primeros 500 chars): ${json.toString().substring(0, json.toString().length > 500 ? 500 : json.toString().length)}...',
      );
      rethrow;
    }
  }

  // Convertir a JSON para MongoDB
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'userId': userId,
      'columns': columns,
      'rows': rows.map((row) => row.toJson()).toList(),
      if (legacyRows != null) 'legacyRows': legacyRows,
      if (thumbnailUrl != null)
        'ThumbnailUrl': thumbnailUrl, // nombre que reconoce el backend (PUT /api/catalogs/<id>)
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Método para crear copia con cambios
  Catalog copyWith({
    String? id,
    String? name,
    String? description,
    String? userId,
    List<String>? columns,
    List<CatalogRow>? rows,
    Map<String, dynamic>? legacyRows,
    String? thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Catalog(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      legacyRows: legacyRows ?? this.legacyRows,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Obtener la primera imagen de las filas del catálogo
  String? getFirstImageFromRows() {
    for (final row in rows) {
      // Buscar en imagen singular
      if (row.files.image != null && row.files.image!.isNotEmpty) {
        return row.files.image;
      }
      // Buscar en lista de imágenes
      if (row.files.images.isNotEmpty) {
        return row.files.images.first;
      }
    }
    return null;
  }

  /// Obtener la URL de la imagen a mostrar (thumbnailUrl o primera de filas)
  String? getDisplayImageUrl() {
    return thumbnailUrl ?? getFirstImageFromRows();
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    userId,
    columns,
    thumbnailUrl,
    rows,
    legacyRows,
    createdAt,
    updatedAt,
  ];
}

/// Modelo de fila de catálogo
class CatalogRow extends Equatable {
  final String id;
  final String? originalId; // UUID string original de MongoDB
  final Map<String, String> data;
  final RowFiles files;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CatalogRow({
    required this.id,
    this.originalId,
    required this.data,
    this.files = const RowFiles(),
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor para crear desde JSON (MongoDB)
  factory CatalogRow.fromJson(Map<String, dynamic> json) {
    // Manejar _id: puede ser String, ObjectId, o Map con $oid
    String idValue = '';
    if (json['_id'] != null) {
      if (json['_id'] is String) {
        idValue = json['_id'] as String;
      } else if (json['_id'] is mongo.ObjectId) {
        // ObjectId en mongo_dart se convierte a String con .oid
        idValue = (json['_id'] as mongo.ObjectId).oid;
      } else if (json['_id'] is Map && json['_id']?['\$oid'] != null) {
        idValue = json['_id']?['\$oid'] ?? '';
      } else {
        idValue = json['_id'].toString();
      }
    } else {
      idValue = json['id']?.toString() ?? '';
    }

    // MongoDB usa mayúsculas: Data, Files, CreatedAt, UpdatedAt
    // Pero también verificar minúsculas por compatibilidad
    Map<String, String> dataMap = {};
    if (json['Data'] != null && json['Data'] is Map) {
      final dataDoc = json['Data'] as Map<String, dynamic>;
      dataMap = dataDoc.map((key, value) => MapEntry(key, value.toString()));
    } else if (json['data'] != null && json['data'] is Map) {
      final dataDoc = json['data'] as Map<String, dynamic>;
      dataMap = dataDoc.map((key, value) => MapEntry(key, value.toString()));
    }

    RowFiles rowFiles = const RowFiles();
    Map<String, dynamic>? filesMap;

    if (json['Files'] != null && json['Files'] is Map) {
      filesMap = json['Files'] as Map<String, dynamic>;
    } else if (json['files'] != null && json['files'] is Map) {
      filesMap = json['files'] as Map<String, dynamic>;
    }

    if (filesMap != null) {
      // Debug: mostrar el contenido del Map antes de parsear
      print('📦 Parseando archivos de fila:');
      print('   filesMap keys: ${filesMap.keys.toList()}');

      // Debug: verificar si FileTitles está presente
      if (filesMap.containsKey('FileTitles')) {
        final fileTitlesRaw = filesMap['FileTitles'];
        print(
          '   📝 FileTitles encontrado (tipo: ${fileTitlesRaw.runtimeType})',
        );
        print('   📝 FileTitles contenido: $fileTitlesRaw');
        if (fileTitlesRaw is Map) {
          print('   📝 FileTitles es Map con ${fileTitlesRaw.length} entradas');
          fileTitlesRaw.forEach((key, value) {
            print(
              '      - "$key": "$value" (tipo valor: ${value.runtimeType})',
            );
          });
        }
      } else if (filesMap.containsKey('fileTitles')) {
        final fileTitlesRaw = filesMap['fileTitles'];
        print(
          '   📝 fileTitles encontrado (minúsculas, tipo: ${fileTitlesRaw.runtimeType})',
        );
        print('   📝 fileTitles contenido: $fileTitlesRaw');
        if (fileTitlesRaw is Map) {
          print('   📝 fileTitles es Map con ${fileTitlesRaw.length} entradas');
          fileTitlesRaw.forEach((key, value) {
            print(
              '      - "$key": "$value" (tipo valor: ${value.runtimeType})',
            );
          });
        }
      } else {
        print('   ⚠️ No se encontró FileTitles ni fileTitles en filesMap');
      }

      rowFiles = RowFiles.fromJson(filesMap);

      // Debug: verificar parsing de archivos
      print('   ✅ Parseado: hasAnyFiles=${rowFiles.hasAnyFiles}');
      if (rowFiles.hasAnyFiles) {
        print('      image: ${rowFiles.image}');
        print('      document: ${rowFiles.document}');
        print('      multimedia: ${rowFiles.multimedia}');
      }
      // Debug: verificar fileTitles parseados
      if (rowFiles.fileTitles.isNotEmpty) {
        print(
          '      📝 fileTitles parseados (${rowFiles.fileTitles.length} entradas): ${rowFiles.fileTitles}',
        );
      } else {
        print('      ⚠️ fileTitles vacío después de parsear');
      }
    } else {
      // Debug: no se encontraron archivos
      print(
        '⚠️ No se encontraron archivos en la fila (Files/files no presentes o no es Map)',
      );
    }

    // Helper para parsear fechas que pueden venir como DateTime, Map con $date, o String
    DateTime? parseRowDateTime(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is DateTime) return dateValue;
      if (dateValue is Map && dateValue['\$date'] != null) {
        // Formato MongoDB: {"$date": "2025-10-12T18:47:09.424Z"}
        final dateStr = dateValue['\$date'].toString();
        return DateTime.tryParse(dateStr);
      }
      if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
      return null;
    }

    DateTime createdAt =
        parseRowDateTime(json['CreatedAt']) ??
        parseRowDateTime(json['createdAt']) ??
        DateTime.now();

    DateTime updatedAt =
        parseRowDateTime(json['UpdatedAt']) ??
        parseRowDateTime(json['updatedAt']) ??
        DateTime.now();

    return CatalogRow(
      id: idValue,
      originalId:
          json['originalId']?.toString() ?? json['OriginalId']?.toString(),
      data: dataMap,
      files: rowFiles,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Convertir a JSON para MongoDB
  Map<String, dynamic> toJson() {
    final filesJson = files.toJson();
    // Debug: verificar que fileTitles se está incluyendo
    print(
      '📝 CatalogRow.toJson - fileTitles en objeto: ${files.fileTitles.length} entradas',
    );
    print('📝 CatalogRow.toJson - fileTitles contenido: ${files.fileTitles}');
    print(
      '📝 CatalogRow.toJson - filesJson contiene FileTitles: ${filesJson.containsKey('FileTitles')}',
    );
    if (filesJson.containsKey('FileTitles')) {
      final fileTitlesInJson = filesJson['FileTitles'];
      if (fileTitlesInJson is Map) {
        print(
          '📝 CatalogRow.toJson - filesJson[FileTitles] es Map con ${fileTitlesInJson.length} entradas: $fileTitlesInJson',
        );
      } else {
        print(
          '📝 CatalogRow.toJson - filesJson[FileTitles] NO es Map, es: ${fileTitlesInJson.runtimeType}',
        );
      }
    }
    return {
      '_id': id,
      if (originalId != null) 'originalId': originalId,
      'Data': data, // MongoDB usa mayúsculas
      'Files': filesJson, // MongoDB usa mayúsculas - contiene FileTitles
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }

  // Método para crear copia con cambios
  CatalogRow copyWith({
    String? id,
    String? originalId,
    Map<String, String>? data,
    RowFiles? files,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatalogRow(
      id: id ?? this.id,
      originalId: originalId ?? this.originalId,
      data: data ?? this.data,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    originalId,
    data,
    files,
    createdAt,
    updatedAt,
  ];
}

/// Archivos asociados a una fila (almacenados en S3)
class RowFiles extends Equatable {
  final String? image;
  final List<String> images;
  final String? document;
  final List<String> documents;
  final String? multimedia;
  final List<String> multimediaFiles;
  // Map de URL -> Título personalizado para cada archivo
  final Map<String, String> fileTitles;

  const RowFiles({
    this.image,
    this.images = const [],
    this.document,
    this.documents = const [],
    this.multimedia,
    this.multimediaFiles = const [],
    this.fileTitles = const {},
  });

  // Factory constructor para crear desde JSON
  // MongoDB usa mayúsculas: Image, Images, Document, Documents, Multimedia, MultimediaFiles
  factory RowFiles.fromJson(Map<String, dynamic> json) {
    // Parsear fileTitles (verificar tanto mayúsculas como minúsculas para compatibilidad)
    Map<String, String> titles = {};

    // Verificar primero FileTitles (mayúsculas) que es lo que guardamos ahora
    if (json['FileTitles'] != null) {
      final fileTitlesValue = json['FileTitles'];
      print(
        '📝 RowFiles.fromJson - FileTitles encontrado, tipo: ${fileTitlesValue.runtimeType}',
      );

      if (fileTitlesValue is Map) {
        final titlesMap = fileTitlesValue;
        print(
          '📝 RowFiles.fromJson - FileTitles es Map con ${titlesMap.length} entradas antes de procesar',
        );

        // Procesar cada entrada del Map
        for (final entry in titlesMap.entries) {
          final keyStr = entry.key.toString();
          final value = entry.value;
          print(
            '   Procesando entrada: "$keyStr" = $value (tipo: ${value.runtimeType})',
          );

          // Convertir valor a string, manejar null y vacíos
          String? valueStr;
          if (value == null) {
            valueStr = null;
          } else if (value is String) {
            valueStr = value.trim();
          } else {
            valueStr = value.toString().trim();
          }

          if (valueStr != null && valueStr.isNotEmpty) {
            titles[keyStr] = valueStr;
            print('   ✅ Añadido a titles: "$keyStr" = "$valueStr"');
          } else {
            print('   ⚠️ Omitido (vacío o null): "$keyStr"');
          }
        }

        print(
          '📝 RowFiles.fromJson - FileTitles parseado (mayúsculas): ${titles.length} entradas finales',
        );
        if (titles.isNotEmpty) {
          print('   Contenido final: $titles');
        }
      } else {
        print(
          '⚠️ RowFiles.fromJson - FileTitles no es un Map, es: ${fileTitlesValue.runtimeType}',
        );
      }
    } else if (json['fileTitles'] != null) {
      // Fallback a minúsculas para compatibilidad
      final fileTitlesValue = json['fileTitles'];
      print(
        '📝 RowFiles.fromJson - fileTitles encontrado (minúsculas), tipo: ${fileTitlesValue.runtimeType}',
      );

      if (fileTitlesValue is Map) {
        final titlesMap = fileTitlesValue;
        print(
          '📝 RowFiles.fromJson - fileTitles es Map con ${titlesMap.length} entradas antes de procesar',
        );

        // Procesar cada entrada del Map
        for (final entry in titlesMap.entries) {
          final keyStr = entry.key.toString();
          final value = entry.value;

          String? valueStr;
          if (value == null) {
            valueStr = null;
          } else if (value is String) {
            valueStr = value.trim();
          } else {
            valueStr = value.toString().trim();
          }

          if (valueStr != null && valueStr.isNotEmpty) {
            titles[keyStr] = valueStr;
          }
        }

        print(
          '📝 RowFiles.fromJson - fileTitles parseado (minúsculas): ${titles.length} entradas finales',
        );
        if (titles.isNotEmpty) {
          print('   Contenido final: $titles');
        }
      }
    } else {
      print(
        '⚠️ RowFiles.fromJson - No se encontró FileTitles ni fileTitles en el JSON',
      );
    }

    // Helper para obtener un string no vacío
    String? getNonEmptyString(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    // Helper para filtrar cadenas vacías de listas
    List<String> filterEmptyStrings(List<dynamic>? list) {
      if (list == null) return [];
      return list
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return RowFiles(
      image: getNonEmptyString(json['Image'] ?? json['image']),
      images: filterEmptyStrings(
        json['Images'] as List<dynamic>? ?? json['images'] as List<dynamic>?,
      ),
      document: getNonEmptyString(json['Document'] ?? json['document']),
      documents: filterEmptyStrings(
        json['Documents'] as List<dynamic>? ??
            json['documents'] as List<dynamic>?,
      ),
      multimedia: getNonEmptyString(json['Multimedia'] ?? json['multimedia']),
      multimediaFiles: filterEmptyStrings(
        json['MultimediaFiles'] as List<dynamic>? ??
            json['multimediaFiles'] as List<dynamic>?,
      ),
      fileTitles: titles,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    // Debug: verificar que fileTitles se está incluyendo
    print(
      '📝 RowFiles.toJson - fileTitles contiene ${fileTitles.length} entradas: $fileTitles',
    );

    // Crear un Map limpio solo con valores no vacíos
    final cleanFileTitles = <String, String>{};
    for (final entry in fileTitles.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        cleanFileTitles[key] = value;
        print('   ✅ Guardando título: "$key" = "$value"');
      } else {
        print('   ⚠️ Omitiendo título vacío o inválido: "$key" = "$value"');
      }
    }

    print(
      '📝 RowFiles.toJson - Total de títulos a guardar: ${cleanFileTitles.length}',
    );

    return {
      if (image != null) 'Image': image, // MongoDB usa mayúsculas
      'Images': images, // MongoDB usa mayúsculas
      if (document != null) 'Document': document, // MongoDB usa mayúsculas
      'Documents': documents, // MongoDB usa mayúsculas
      if (multimedia != null)
        'Multimedia': multimedia, // MongoDB usa mayúsculas
      'MultimediaFiles': multimediaFiles, // MongoDB usa mayúsculas
      // Incluir FileTitles siempre (incluso si está vacío) para mantener consistencia
      // Usar 'FileTitles' con mayúscula para consistencia con MongoDB
      'FileTitles': cleanFileTitles,
    };
  }

  // Método para crear copia con cambios
  RowFiles copyWith({
    String? image,
    List<String>? images,
    String? document,
    List<String>? documents,
    String? multimedia,
    List<String>? multimediaFiles,
    Map<String, String>? fileTitles,
  }) {
    return RowFiles(
      image: image ?? this.image,
      images: images ?? this.images,
      document: document ?? this.document,
      documents: documents ?? this.documents,
      multimedia: multimedia ?? this.multimedia,
      multimediaFiles: multimediaFiles ?? this.multimediaFiles,
      fileTitles: fileTitles ?? this.fileTitles,
    );
  }

  bool get hasAnyFiles {
    return (image != null && image!.isNotEmpty) ||
        images.isNotEmpty ||
        (document != null && document!.isNotEmpty) ||
        documents.isNotEmpty ||
        (multimedia != null && multimedia!.isNotEmpty) ||
        multimediaFiles.isNotEmpty;
  }

  @override
  List<Object?> get props => [
    image,
    images,
    document,
    documents,
    multimedia,
    multimediaFiles,
    fileTitles,
  ];
}
