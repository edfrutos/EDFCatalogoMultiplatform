import 'package:equatable/equatable.dart';

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
    return User(
      id: json['_id'] is String
          ? json['_id']
          : (json['_id']?['\$oid'] ?? json['id'] ?? ''),
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      fullName: json['fullName'],
      phone: json['phone'],
      company: json['company'],
      address: json['address'],
      occupation: json['occupation'],
      profileImageUrl: json['profileImageUrl'],
      isActive: json['isActive'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
    );
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

