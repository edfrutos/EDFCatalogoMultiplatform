import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
// export.dart expone Scrypt, PBKDF2KeyDerivator, ScryptParameters,
// Pbkdf2Parameters, HMac, SHA256Digest, SHA1Digest sin adivinar rutas internas.
import 'package:pointycastle/export.dart';

/// Hash y verificación de contraseñas de usuario del catálogo.
///
/// Formato canónico al guardar: SHA-256 de UTF-8, en Base64.
///
/// [verify] acepta además, para no dejar fuera a usuarios creados por otros
/// sistemas de la plataforma:
///  - texto plano (legado)
///  - SHA-384 / SHA-512 en Base64
///  - SHA-256 en hex (seed antiguo)
///  - **hashes de Werkzeug/Flask**: `scrypt:N:r:p$salt$hex` y
///    `pbkdf2:algo[:iter]$salt$hex` — la base de datos `edf_catalogotablas`
///    tiene los usuarios con este formato (app Flask + scripts de migración).
class PasswordHasher {
  PasswordHasher._();

  /// Hash canónico para persistir (crear / actualizar contraseña).
  static String hash(String password) {
    return base64Encode(sha256.convert(utf8.encode(password)).bytes);
  }

  /// Comprueba [password] contra el valor almacenado en Mongo.
  static bool verify(String password, String stored) {
    if (stored.isEmpty) return false;
    if (stored == password) return true;

    // Werkzeug (Flask): scrypt:... / pbkdf2:...
    if (stored.startsWith('scrypt:') || stored.startsWith('pbkdf2:')) {
      return _verifyWerkzeug(password, stored);
    }

    final bytes = utf8.encode(password);
    if (stored == hash(password)) return true;
    if (stored == base64Encode(sha512.convert(bytes).bytes)) return true;
    if (stored == base64Encode(sha384.convert(bytes).bytes)) return true;
    // Seed histórico: `sha256.convert(bytes).toString()` (hex, no Base64).
    if (stored == sha256.convert(bytes).toString()) return true;
    return false;
  }

  // ── Werkzeug ────────────────────────────────────────────────────────────

  /// Formato: `<method>$<salt>$<hexhash>` donde `<method>` es
  /// `scrypt:N:r:p` o `pbkdf2:hashname[:iterations]`.
  static bool _verifyWerkzeug(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 3) return false;
    final method = parts[0];
    final salt = utf8.encode(parts[1]);
    final expectedHex = parts[2].toLowerCase();
    if (expectedHex.isEmpty) return false;

    final Uint8List derived;
    try {
      if (method.startsWith('scrypt:')) {
        derived = _scrypt(utf8.encode(password), salt, method);
      } else if (method.startsWith('pbkdf2:')) {
        derived = _pbkdf2(utf8.encode(password), salt, method);
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
    return _constantTimeHexEquals(_toHex(derived), expectedHex);
  }

  /// `scrypt:N:r:p` — Werkzeug usa siempre dklen = 64.
  static Uint8List _scrypt(
    List<int> password,
    List<int> salt,
    String method,
  ) {
    final p = method.split(':'); // ['scrypt', N, r, p]
    if (p.length != 4) throw const FormatException('scrypt params');
    final n = int.parse(p[1]);
    final r = int.parse(p[2]);
    final parallelism = int.parse(p[3]);
    const dkLen = 64;

    final d = Scrypt()
      ..init(ScryptParameters(
        n,
        r,
        parallelism,
        dkLen,
        Uint8List.fromList(salt),
      ));
    final out = Uint8List(dkLen);
    d.deriveKey(Uint8List.fromList(password), 0, out, 0);
    return out;
  }

  /// `pbkdf2:hashname[:iterations]` — Werkzeug: dklen = tamaño del digest,
  /// iteraciones por defecto 260000 (sha256) si no vienen en la cadena.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    String method,
  ) {
    final p = method.split(':'); // ['pbkdf2', hashname, iter?]
    if (p.length < 2) throw const FormatException('pbkdf2 params');
    final hashName = p[1].toLowerCase();
    final iterations = p.length >= 3 ? int.parse(p[2]) : 260000;

    late final HMac mac;
    late final int dkLen;
    switch (hashName) {
      case 'sha256':
        mac = HMac(SHA256Digest(), 64);
        dkLen = 32;
        break;
      case 'sha1':
        mac = HMac(SHA1Digest(), 64);
        dkLen = 20;
        break;
      default:
        throw FormatException('pbkdf2 hash no soportado: $hashName');
    }

    final d = PBKDF2KeyDerivator(mac)
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, dkLen));
    return d.process(Uint8List.fromList(password));
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static bool _constantTimeHexEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
