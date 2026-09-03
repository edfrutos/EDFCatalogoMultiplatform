import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:edfcatalogo_crypto/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  const password = 'Admin1234!';

  test('hash es SHA-256 Base64 y es determinista', () {
    final expected = base64Encode(sha256.convert(utf8.encode(password)).bytes);
    expect(PasswordHasher.hash(password), expected);
    expect(PasswordHasher.hash(password), PasswordHasher.hash(password));
  });

  test('verify acepta el hash canónico', () {
    expect(PasswordHasher.verify(password, PasswordHasher.hash(password)), isTrue);
    expect(PasswordHasher.verify(password, PasswordHasher.hash('otra')), isFalse);
  });

  test('verify acepta texto plano legado', () {
    expect(PasswordHasher.verify(password, password), isTrue);
  });

  test('verify acepta SHA-512 y SHA-384 Base64', () {
    final bytes = utf8.encode(password);
    expect(
      PasswordHasher.verify(password, base64Encode(sha512.convert(bytes).bytes)),
      isTrue,
    );
    expect(
      PasswordHasher.verify(password, base64Encode(sha384.convert(bytes).bytes)),
      isTrue,
    );
  });

  test('verify acepta SHA-256 hex del seed antiguo', () {
    final hex = sha256.convert(utf8.encode(password)).toString();
    expect(hex, isNot(PasswordHasher.hash(password)));
    expect(PasswordHasher.verify(password, hex), isTrue);
  });

  test('verify rechaza vacío y basura', () {
    expect(PasswordHasher.verify(password, ''), isFalse);
    expect(PasswordHasher.verify(password, 'no-es-un-hash'), isFalse);
  });

  group('Werkzeug / Flask (usuarios legados)', () {
    // Vectores generados con hashlib de CPython para password 'Admin1234!' y
    // salt 'abcdefghij123456'  (ver scripts/… o el bloque python del PR).
    const wkScrypt =
        r'scrypt:32768:8:1$abcdefghij123456$8bc4e2dce4ff7718f9d4ddd2e78400cb2178cdca2b1c2fcc1cd85d579842648553b9c8865e8311c7859f53da2eb419eee0d0300e391fed40b47257e4a564e922';
    const wkPbkdf2_260k =
        r'pbkdf2:sha256:260000$abcdefghij123456$4bc43af72a4af8ce68f1d1aece455da69f2cc3a0855339fcd747b947091187c3';
    const wkPbkdf2_600k =
        r'pbkdf2:sha256:600000$abcdefghij123456$4d2e8d504e5e1dcc280a4e9abad1007da4781cc10cc5fc241cf49677d526b76d';

    test('scrypt:N:r:p\$salt\$hex', () {
      expect(PasswordHasher.verify(password, wkScrypt), isTrue);
      expect(PasswordHasher.verify('mala', wkScrypt), isFalse);
    });

    test('pbkdf2:sha256:iter\$salt\$hex', () {
      expect(PasswordHasher.verify(password, wkPbkdf2_260k), isTrue);
      expect(PasswordHasher.verify(password, wkPbkdf2_600k), isTrue);
      expect(PasswordHasher.verify('mala', wkPbkdf2_260k), isFalse);
    });

    test('cadena malformada no revienta', () {
      expect(PasswordHasher.verify(password, r'scrypt:32768:8:1$solo-salt'),
          isFalse);
      expect(PasswordHasher.verify(password, r'scrypt:bad$salt$deadbeef'),
          isFalse);
    });
  });
}
