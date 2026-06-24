import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../auth/jwt_service.dart';

const _jsonHeaders = {'Content-Type': 'application/json; charset=utf-8'};

/// Respuesta 200 con body JSON.
Response ok(dynamic data) =>
    Response.ok(jsonEncode(data), headers: _jsonHeaders);

/// Respuesta de error con código HTTP y mensaje.
Response error(String message, int status) => Response(
      status,
      body: jsonEncode({'error': message}),
      headers: _jsonHeaders,
    );

/// Extrae y valida el JWT. Devuelve null y escribe error si no es válido.
Map<String, dynamic>? requireAuth(Request req) =>
    JwtService.fromRequest(req.headers);

/// Extrae y valida el JWT, además verifica que isAdmin=true.
Map<String, dynamic>? requireAdmin(Request req) {
  final payload = requireAuth(req);
  if (payload == null) return null;
  if (!JwtService.isAdmin(payload)) return null;
  return payload;
}
