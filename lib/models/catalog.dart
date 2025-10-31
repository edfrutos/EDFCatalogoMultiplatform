import 'package:equatable/equatable.dart';

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
    return Catalog(
      id: json['_id'] is String
          ? json['_id']
          : (json['_id']?['\$oid'] ?? json['id'] ?? ''),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      userId: json['userId'] ?? '',
      columns: (json['columns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rows: (json['rows'] as List<dynamic>?)
              ?.map((e) => CatalogRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      legacyRows: json['legacyRows'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
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
    return CatalogRow(
      id: json['_id'] is String
          ? json['_id']
          : (json['_id']?['\$oid'] ?? json['id'] ?? ''),
      originalId: json['originalId'],
      data: (json['data'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value.toString())) ??
          {},
      files: json['files'] != null
          ? RowFiles.fromJson(json['files'] as Map<String, dynamic>)
          : const RowFiles(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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

  const RowFiles({
    this.image,
    this.images = const [],
    this.document,
    this.documents = const [],
    this.multimedia,
    this.multimediaFiles = const [],
  });

  // Factory constructor para crear desde JSON
  factory RowFiles.fromJson(Map<String, dynamic> json) {
    return RowFiles(
      image: json['image'],
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      document: json['document'],
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      multimedia: json['multimedia'],
      multimediaFiles: (json['multimediaFiles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
  }) {
    return RowFiles(
      image: image ?? this.image,
      images: images ?? this.images,
      document: document ?? this.document,
      documents: documents ?? this.documents,
      multimedia: multimedia ?? this.multimedia,
      multimediaFiles: multimediaFiles ?? this.multimediaFiles,
    );
  }

  @override
  List<Object?> get props => [
        image,
        images,
        document,
        documents,
        multimedia,
        multimediaFiles,
      ];
}

