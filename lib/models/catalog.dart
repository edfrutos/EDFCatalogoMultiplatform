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
          for (final e in rowsList) {
            if (e is Map<String, dynamic>) {
              try {
                final row = CatalogRow.fromJson(e);
                processRow(row);
              } catch (e) {
                print('⚠️ Error parseando fila: $e');
              }
            } else {
              print('⚠️ Fila no es un Map, es: ${e.runtimeType}');
            }
          }
        }
      } else if (json['rows'] != null) {
        final rowsList = json['rows'] as List<dynamic>?;
        if (rowsList != null) {
          for (final e in rowsList) {
            if (e is Map<String, dynamic>) {
              try {
                final row = CatalogRow.fromJson(e);
                processRow(row);
              } catch (e) {
                print('⚠️ Error parseando fila: $e');
              }
            } else {
              print('⚠️ Fila no es un Map, es: ${e.runtimeType}');
            }
          }
        }
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

      return Catalog(
        id: idValue,
        name: name.toString(),
        description: description.toString(),
        userId: owner.toString(),
        columns: columns,
        rows: rows,
        legacyRows: legacyRowsValue,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    userId,
    columns,
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
      print('   filesMap content: $filesMap');

      rowFiles = RowFiles.fromJson(filesMap);

      // Debug: verificar parsing de archivos
      print('   ✅ Parseado: hasAnyFiles=${rowFiles.hasAnyFiles}');
      if (rowFiles.hasAnyFiles) {
        print('      image: ${rowFiles.image}');
        print('      document: ${rowFiles.document}');
        print('      multimedia: ${rowFiles.multimedia}');
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
    return {
      '_id': id,
      if (originalId != null) 'originalId': originalId,
      'data': data,
      'files': files.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
    // Parsear fileTitles
    Map<String, String> titles = {};
    if (json['fileTitles'] != null && json['fileTitles'] is Map) {
      final titlesMap = json['fileTitles'] as Map;
      titles = titlesMap.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
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
    return {
      if (image != null) 'image': image,
      'images': images,
      if (document != null) 'document': document,
      'documents': documents,
      if (multimedia != null) 'multimedia': multimedia,
      'multimediaFiles': multimediaFiles,
      if (fileTitles.isNotEmpty) 'fileTitles': fileTitles,
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
