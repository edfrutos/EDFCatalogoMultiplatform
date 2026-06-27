// test/integration/login_flow_test.dart
//
// Tests de flujo de login/logout.
// Cubren: renderizado, validación local, autenticación mock, cierre de sesión.
// No requieren dispositivo ni conexión a MongoDB.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:edfcatalogomultiplatform/viewmodels/auth_viewmodel.dart';

import 'test_helpers.dart';

void main() {
  late MockMongoService mongo;
  late MockKeychainService keychain;

  setUp(() {
    mongo = MockMongoService();
    keychain = MockKeychainService();
    disableGoogleFontsFetch();
  });

  // ── Renderizado inicial ────────────────────────────────────────────────────

  group('LoginView — pantalla inicial', () {
    testWidgets('muestra al menos dos campos de texto al arrancar',
        (tester) async {
      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await tester.pumpWidget(buildApp(authVm));
      await tester.pump();

      // Email/usuario + contraseña
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('el botón de login está presente', (tester) async {
      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await tester.pumpWidget(buildApp(authVm));
      await tester.pump();

      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  // ── Validación local ───────────────────────────────────────────────────────

  group('LoginView — validación de campos', () {
    testWidgets('rechaza credenciales vacías sin llamar a Mongo', (tester) async {
      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await tester.pumpWidget(buildApp(authVm));
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // LoginView valida campos vacíos con _formKey.validate() antes de llamar
      // a signIn(), así que authVm.errorMessage queda null. Solo verificamos
      // que Mongo no fue llamado y el estado no cambió.
      expect(authVm.isAuthenticated, isFalse);
      verifyNever(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      );
    });
  });

  // ── Autenticación ──────────────────────────────────────────────────────────

  group('LoginView — autenticación', () {
    testWidgets('autentica con credenciales correctas', (tester) async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: 'test@edf.test',
          password: 'Test1234!',
        ),
      ).thenAnswer((_) async => testUser);
      stubKeychainForLogin(keychain);

      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await tester.pumpWidget(buildApp(authVm));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test@edf.test');
      await tester.enterText(fields.at(1), 'Test1234!');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUser?.email, 'test@edf.test');
      expect(authVm.errorMessage, isNull);
    });

    testWidgets('establece errorMessage con credenciales incorrectas',
        (tester) async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => null);

      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await tester.pumpWidget(buildApp(authVm));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'bad@edf.test');
      await tester.enterText(fields.at(1), 'badpass');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.errorMessage, isNotNull);
    });
  });

  // ── Cierre de sesión ───────────────────────────────────────────────────────

  group('signOut', () {
    testWidgets('limpia el estado de autenticación', (tester) async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => testUser);
      stubKeychainForLogin(keychain);

      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);

      // Login
      await authVm.signIn(
          emailOrUsername: 'test@edf.test', password: 'Test1234!');
      expect(authVm.isAuthenticated, isTrue);

      // Logout
      authVm.signOut();

      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUser, isNull);
      expect(authVm.errorMessage, isNull);
    });

    testWidgets('llama a keychain.clearAuthData al hacer logout', (tester) async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => testUser);
      stubKeychainForLogin(keychain);

      final authVm =
          AuthViewModel(mongoService: mongo, keychainService: keychain);
      await authVm.signIn(
          emailOrUsername: 'test@edf.test', password: 'Test1234!');

      authVm.signOut();

      verify(() => keychain.clearAuthData()).called(1);
    });
  });
}
