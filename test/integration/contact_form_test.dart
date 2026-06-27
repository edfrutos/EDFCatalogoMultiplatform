// test/integration/contact_form_test.dart
//
// Tests del formulario de contacto (ContactView).
// Cubren: renderizado, pre-relleno con datos del usuario autenticado,
// validación de campos y formato de email.
// No requieren dispositivo ni conexión a MongoDB.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:edfcatalogomultiplatform/models/user.dart';
import 'package:edfcatalogomultiplatform/viewmodels/auth_viewmodel.dart';
import 'package:edfcatalogomultiplatform/views/screens/contact_view.dart';

import 'test_helpers.dart';

void main() {
  late MockMongoService mongo;
  late MockKeychainService keychain;

  setUp(() {
    mongo = MockMongoService();
    keychain = MockKeychainService();
    disableGoogleFontsFetch();
  });

  // Construye ContactView con el usuario [user] ya autenticado.
  Future<void> pumpContact(
    WidgetTester tester, {
    User user = testUser,
  }) async {
    when(
      () => mongo.authenticateUser(
        emailOrUsername: any(named: 'emailOrUsername'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => user);
    stubKeychainForLogin(keychain);

    final authVm =
        AuthViewModel(mongoService: mongo, keychainService: keychain);
    await authVm.signIn(
        emailOrUsername: user.email, password: 'Test1234!');

    await tester.pumpWidget(
      buildIsolated(authVm: authVm, child: const ContactView()),
    );
    // addPostFrameCallback necesita un frame extra para pre-rellenar campos
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ── Renderizado ────────────────────────────────────────────────────────────

  group('ContactView — renderizado', () {
    testWidgets('muestra exactamente 4 campos de texto', (tester) async {
      await pumpContact(tester);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('muestra el botón de envío', (tester) async {
      await pumpContact(tester);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  // ── Pre-relleno ────────────────────────────────────────────────────────────

  group('ContactView — pre-relleno con datos del usuario', () {
    testWidgets('el campo de nombre contiene el nombre del usuario autenticado',
        (tester) async {
      await pumpContact(tester, user: testUser);

      final controller = tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller;
      expect(controller?.text, testUser.name);
    });

    testWidgets('el campo de email contiene el email del usuario autenticado',
        (tester) async {
      await pumpContact(tester, user: testUser);

      final controller = tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller;
      expect(controller?.text, testUser.email);
    });
  });

  // ── Validación ─────────────────────────────────────────────────────────────

  group('ContactView — validación de formulario', () {
    testWidgets('muestra error si el nombre está vacío', (tester) async {
      await pumpContact(tester);

      // Vaciar el campo de nombre
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
    });

    testWidgets('muestra error si el email está vacío', (tester) async {
      await pumpContact(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('El email es obligatorio'), findsOneWidget);
    });

    testWidgets('muestra error si el email no tiene @', (tester) async {
      await pumpContact(tester);

      await tester.enterText(
          find.byType(TextFormField).at(1), 'correo-sin-arroba');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Email no válido'), findsOneWidget);
    });

    testWidgets('muestra error si el asunto está vacío', (tester) async {
      await pumpContact(tester);

      // Asegurar que los campos requeridos previos están rellenos
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('El asunto es obligatorio'), findsOneWidget);
    });

    testWidgets('muestra error si el mensaje está vacío', (tester) async {
      await pumpContact(tester);

      await tester.enterText(find.byType(TextFormField).at(3), '');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('El mensaje es obligatorio'), findsOneWidget);
    });

    testWidgets('muestra error si el mensaje tiene menos de 10 caracteres',
        (tester) async {
      await pumpContact(tester);

      await tester.enterText(find.byType(TextFormField).at(3), 'Corto');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('El mensaje es demasiado corto'), findsOneWidget);
    });
  });
}
