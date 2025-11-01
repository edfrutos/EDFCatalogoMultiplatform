import 'package:equatable/equatable.dart';

/// Definición de columna con metadatos y reglas de validación
class ColumnDefinition extends Equatable {
  final String name;
  final String dataType; // 'text', 'number', 'date', 'url', 'email'
  final bool required;
  final int? minLength;
  final int? maxLength;
  final double? minValue;
  final double? maxValue;
  final String? defaultValue;
  final String? description;
  final List<String>? allowedValues; // Para select/dropdown

  const ColumnDefinition({
    required this.name,
    this.dataType = 'text',
    this.required = false,
    this.minLength,
    this.maxLength,
    this.minValue,
    this.maxValue,
    this.defaultValue,
    this.description,
    this.allowedValues,
  });

  factory ColumnDefinition.fromJson(Map<String, dynamic> json) {
    return ColumnDefinition(
      name: json['name'] ?? '',
      dataType: json['dataType'] ?? 'text',
      required: json['required'] ?? false,
      minLength: json['minLength'],
      maxLength: json['maxLength'],
      minValue: json['minValue']?.toDouble(),
      maxValue: json['maxValue']?.toDouble(),
      defaultValue: json['defaultValue'],
      description: json['description'],
      allowedValues: json['allowedValues'] != null
          ? List<String>.from(json['allowedValues'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dataType': dataType,
      'required': required,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (defaultValue != null) 'defaultValue': defaultValue,
      if (description != null) 'description': description,
      if (allowedValues != null) 'allowedValues': allowedValues,
    };
  }

  ColumnDefinition copyWith({
    String? name,
    String? dataType,
    bool? required,
    int? minLength,
    int? maxLength,
    double? minValue,
    double? maxValue,
    String? defaultValue,
    String? description,
    List<String>? allowedValues,
  }) {
    return ColumnDefinition(
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      required: required ?? this.required,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      defaultValue: defaultValue ?? this.defaultValue,
      description: description ?? this.description,
      allowedValues: allowedValues ?? this.allowedValues,
    );
  }

  @override
  List<Object?> get props => [
        name,
        dataType,
        required,
        minLength,
        maxLength,
        minValue,
        maxValue,
        defaultValue,
        description,
        allowedValues,
      ];
}

