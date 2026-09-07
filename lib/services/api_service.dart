// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:edfcatalogo_crypto/s3_content_type.dart';
import 'package:edfcatalogo_crypto/s3_object_key.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/catalog.dart';
import '../utils/env_config.dart';

/// Cliente HTTP para el servidor API Dart/Shelf.
/// Solo se usa cuando [kIsWeb] es true.
///
/// Todas las operaciones replican la interfaz de [MongoService] pero
/// hacen llamadas REST en lugar de conexiones TCP directas a MongoDB.
class ApiService {
  static final ApiService _instance = ApiService._();
  static ApiService get instance => _instance;
  ApiService._();

  String? _token;
  String? _userId;

  // ── Configuración ─────────────────────────────────────────────────────────

  String get _baseUrl {
    final url = EnvConfig.apiBaseUrl;
    // Quitar trailing slash para consistencia
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  bool get isAuthenticated => _token != null;
  String? get currentUserId => _userId;
  String? get currentToken => _token;

  void setToken(String token, {String? userId}) {
    _token = token;
    _userId = userId;
    print('🔑 ApiService: token configurado para userId=$userId');
  }

  void clearToken() {
    _token = null;
    _userId = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$_baseUrl/$path');
    return query != null ? base.replace(queryParameters: query) : base;
  }

  Future<Map<String, dynamic>?> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    try {
      final res = await http.get(_uri(path, query), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      _logError('GET $path', res);
      return null;
    } catch (e) {
      print('❌ ApiService GET $path: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      _logError('POST $path', res);
      return null;
    } catch (e) {
      print('❌ ApiService POST $path: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.put(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      _logError('PUT $path', res);
      return null;
    } catch (e) {
      print('❌ ApiService PUT $path: $e');
      rethrow;
    }
  }

  Future<bool> _delete(String path, [Map<String, dynamic>? body]) async {
    try {
      final req = http.Request('DELETE', _uri(path));
      req.headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send();
      return streamed.statusCode == 200;
    } catch (e) {
      print('❌ ApiService DELETE $path: $e');
      rethrow;
    }
  }

  void _logError(String method, http.Response res) {
    print('⚠️ ApiService $method → ${res.statusCode}: ${res.body}');
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Login: devuelve el User autenticado y guarda el JWT internamente.
  Future<User?> login({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final res = await http.post(
        _uri('api/auth/login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'emailOrUsername': emailOrUsername,
          'password': password,
        }),
      );
      if (res.statusCode != 200) {
        print('❌ Login fallido ${res.statusCode}: ${res.body}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userJson);
      setToken(data['token'] as String, userId: user.id);
      return user;
    } catch (e) {
      print('❌ ApiService login: $e');
      rethrow;
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<User>> getAllUsers() async {
    final data = await _get('api/users/');
    if (data == null) return [];
    final list = data['users'] as List<dynamic>? ?? [];
    return list
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> getUserStats() async {
    final data = await _get('api/users/stats');
    if (data == null) return {'total': 0, 'admins': 0, 'regular': 0};
    return {
      'total': data['total'] as int? ?? 0,
      'admins': data['admins'] as int? ?? 0,
      'regular': data['regular'] as int? ?? 0,
    };
  }

  Future<User?> getUserById(String id) async {
    final data = await _get('api/users/$id');
    if (data == null) return null;
    return User.fromJson(data);
  }

  Future<User?> getUserByEmail(String email) async {
    final encoded = Uri.encodeComponent(email);
    final data = await _get('api/users/by-email/$encoded');
    if (data == null) return null;
    return User.fromJson(data);
  }

  Future<bool> saveContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    final data = await _post('api/contact/', {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
    return data?['saved'] as bool? ?? false;
  }

  Future<bool> checkUserExists(String email) async {
    final data = await _post('api/users/check-exists', {'email': email});
    return data?['exists'] as bool? ?? false;
  }

  Future<void> createUser({
    required String email,
    required String username,
    required String name,
    required String password,
    String role = 'user',
    String? fullName,
    String? phone,
    String? company,
    String? address,
    String? occupation,
  }) async {
    await _post('api/users/', {
      'email': email,
      'username': username,
      'name': name,
      'password': password,
      'role': role,
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (company != null) 'company': company,
      if (address != null) 'address': address,
      if (occupation != null) 'occupation': occupation,
    });
  }

  Future<bool> updateUser(String id, Map<String, dynamic> updates) async {
    final data = await _put('api/users/$id', updates);
    return data?['updated'] as bool? ?? false;
  }

  Future<bool> deleteUser(String id) async {
    return _delete('api/users/$id');
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<void> savePasswordResetToken(String email, String token) async {
    await _post('api/users/password/reset-token', {
      'email': email,
      'token': token,
    });
  }

  Future<bool> verifyPasswordResetToken(String email, String token) async {
    final data = await _post('api/users/password/verify-token', {
      'email': email,
      'token': token,
    });
    return data?['valid'] as bool? ?? false;
  }

  Future<void> updatePassword(String email, String newPassword) async {
    await _put('api/users/password', {
      'email': email,
      'newPassword': newPassword,
    });
  }

  Future<void> clearPasswordResetToken(String email) async {
    await _delete('api/users/password/token', {'email': email});
  }

  // ── Catalogs ──────────────────────────────────────────────────────────────

  Future<List<Catalog>> getCatalogs(
    String userId, {
    bool isAdmin = false,
    String? userEmail,
  }) async {
    final data = await _get('api/catalogs/', {
      'userId': userId,
      'isAdmin': isAdmin.toString(),
      if (userEmail != null) 'userEmail': userEmail,
    });
    if (data == null) return [];
    final list = data['catalogs'] as List<dynamic>? ?? [];
    return list
        .map((e) => Catalog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Catalog?> getCatalogById(String id) async {
    final data = await _get('api/catalogs/$id');
    if (data == null) return null;
    return Catalog.fromJson(data);
  }

  Future<Catalog> createCatalog({
    required String name,
    required String description,
    required String userId,
    required List<String> columns,
    String? thumbnailUrl,
    String? userEmail,
  }) async {
    final data = await _post('api/catalogs/', {
      'name': name,
      'description': description,
      'owner': userEmail ?? userId,
      'createdBy': userId,
      'columns': columns,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    });
    if (data == null) throw Exception('Error al crear catálogo');
    return Catalog.fromJson(data);
  }

  Future<Catalog> createCatalogFromMap(Map<String, dynamic> catalogData) async {
    final data = await _post('api/catalogs/', catalogData);
    if (data == null) throw Exception('Error al crear catálogo');
    return Catalog.fromJson(data);
  }

  Future<bool> updateCatalogFromObject(Catalog catalog) async {
    final data = await _put('api/catalogs/${catalog.id}', catalog.toJson());
    return data?['updated'] as bool? ?? false;
  }

  Future<bool> updateCatalog(String id, Map<String, dynamic> updates) async {
    final data = await _put('api/catalogs/$id', updates);
    return data?['updated'] as bool? ?? false;
  }

  Future<bool> deleteCatalog(String id) async {
    return _delete('api/catalogs/$id');
  }

  // ── S3 ────────────────────────────────────────────────────────────────────

  /// Genera una URL pre-firmada para leer un objeto S3.
  Future<Uri> getPresignedUrl(String key) async {
    final data = await _get('api/s3/presign', {'key': key});
    final url = data?['url'] as String? ?? '';
    if (url.isEmpty) throw Exception('No se pudo obtener URL pre-firmada');
    return Uri.parse(url);
  }

  /// Sube bytes a S3 a través del servidor API.
  ///
  /// Si hay [userId]/[catalogId]/[fileType], la key es la canónica
  /// (`users/.../catalogs/.../{kind}/uuid.ext`). [folder] queda como
  /// fallback para APIs viejas (mismo prefijo).
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? userId,
    String? catalogId,
    String? fileType,
    String folder = 'uploads',
    String? contentType,
  }) async {
    try {
      final mime = S3ContentType.isGeneric(contentType)
          ? S3ContentType.fromFileName(fileName)
          : contentType!;
      final prefix = (userId != null &&
              catalogId != null &&
              fileType != null)
          ? S3ObjectKey.prefix(
              userId: userId,
              catalogId: catalogId,
              kind: fileType,
            )
          : folder;
      final headers = <String, String>{
        'Authorization': 'Bearer $_token',
        'Content-Type': mime,
        // Percent-encode: las cabeceras HTTP solo admiten ISO-8859-1, y
        // nombres de archivo con tildes/ñ en NFD (típico en macOS) rompían el
        // fetch entero en el navegador antes de llegar al servidor.
        'X-File-Name': Uri.encodeComponent(fileName),
        'X-Folder': prefix,
      };
      if (userId != null) headers['X-User-Id'] = userId;
      if (catalogId != null) headers['X-Catalog-Id'] = catalogId;
      if (fileType != null) headers['X-File-Type'] = fileType;

      final res = await http.post(
        _uri('api/s3/upload'),
        headers: headers,
        body: bytes,
      );
      if (res.statusCode != 200) {
        throw Exception('Upload error ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e) {
      print('❌ ApiService uploadBytes: $e');
      rethrow;
    }
  }

  /// Elimina un archivo de S3 a través del servidor API.
  Future<void> deleteS3File(String key) async {
    await _delete('api/s3/delete?key=${Uri.encodeComponent(key)}');
  }
}
