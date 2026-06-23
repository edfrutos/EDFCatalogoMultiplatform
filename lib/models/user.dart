import 'package:equatable/equatable.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

/// Modelo de usuario completo
class User extends Equatable {
  final String id;
  final String email;
  final String username; // Nombre de usuario único
  final String name; // Nombre para mostrar (puede ser nombre completo)
  final bool isAdmin;

  // Campos opcionales
  final String? fullName; // Nombre y apellidos completos
  final String? phone;
  final String? company;
  final String? address;
  final String? occupation;
  final String? profileImageUrl;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    required this.isAdmin,
    this.fullName,
    this.phone,
    this.company,
    this.address,
    this.occupation,
    this.profileImageUrl,
    this.isActive,
    this.createdAt,
    this.lastLoginAt,
  });

  // Factory constructor para crear desde JSON (MongoDB)
  factory User.fromJson(Map<String, dynamic> json) {
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

    // Convertir Role a isAdmin (Role puede ser "Admin", "admin", "user", etc.)
    final role =
        json['Role']?.toString().toLowerCase() ??
        json['role']?.toString().toLowerCase() ??
        '';
    final isAdminValue = role == 'admin';

    return User(
      id: idValue,
      // MongoDB usa Email/Username con mayúsculas, pero también verificar minúsculas
      email: json['Email']?.toString() ?? json['email']?.toString() ?? '',
      username:
          json['Username']?.toString() ?? json['username']?.toString() ?? '',
      name:
          json['Name']?.toString() ??
          json['name']?.toString() ??
          json['nombre']?.toString() ??
          '',
      isAdmin: isAdminValue,
      fullName: json['FullName']?.toString() ?? json['fullName']?.toString(),
      phone: json['Phone']?.toString() ?? json['phone']?.toString(),
      company: json['Company']?.toString() ?? json['company']?.toString(),
      address: json['Address']?.toString() ?? json['address']?.toString(),
      occupation:
          json['Occupation']?.toString() ?? json['occupation']?.toString(),
      profileImageUrl:
          json['ProfileImageUrl']?.toString() ??
          json['profileImageUrl']?.toString(),
      isActive:
          json['IsActive'] ?? json['isActive'] ?? json['is_active'] ?? true,
      createdAt:
          _parseDateTime(json['CreatedAt']) ??
          _parseDateTime(json['createdAt']),
      lastLoginAt:
          _parseDateTime(json['LastLoginAt']) ??
          _parseDateTime(json['lastLoginAt']),
    );
  }

  // Helper para parsear fechas desde MongoDB
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Map && value['\$date'] != null) {
      final dateValue = value['\$date'];
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  // Convertir a JSON para MongoDB
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'username': username,
      'name': name,
      'isAdmin': isAdmin,
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (company != null) 'company': company,
      if (address != null) 'address': address,
      if (occupation != null) 'occupation': occupation,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (isActive != null) 'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
    };
  }

  // Método para crear copia con cambios
  User copyWith({
    String? id,
    String? email,
    String? username,
    String? name,
    bool? isAdmin,
    String? fullName,
    String? phone,
    String? company,
    String? address,
    String? occupation,
    String? profileImageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      name: name ?? this.name,
      isAdmin: isAdmin ?? this.isAdmin,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      address: address ?? this.address,
      occupation: occupation ?? this.occupation,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // Mock para pruebas
  static User mock({String? email}) {
    return User(
      id: 'mock_id_123',
      email: email ?? 'demo@edf.com',
      username: 'demo',
      name: 'Usuario Demo',
      isAdmin: true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    username,
    name,
    isAdmin,
    fullName,
    phone,
    company,
    address,
    occupation,
    profileImageUrl,
    isActive,
    createdAt,
    lastLoginAt,
  ];
}
