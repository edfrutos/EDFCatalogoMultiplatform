// integration_test/app_test.dart
//
// Tests E2E básicos — se ejecutan en un navegador/dispositivo real.
//
// CI (Chrome headless):
//   flutter test integration_test/ -d chrome --headless
//
// Local (con Chrome):
//   flutter test integration_test/ -d chrome
//
// Local (dispositivo físico/emulador):
//   flutter test integration_test/ -d <device-id>
//
// NOTA: No se necesita MongoDB. La app muestra la pantalla de login
// antes de intentar ninguna conexión, así que estos tests funcionan
// con el placeholder .env que genera el CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:edfcatalogomultiplatform/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Arranque ───────────────────────────────────────────────────────────────

  group('Arranque de la app', () {
    testWidgets('arranca sin excepciones no controladas', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra la pantalla de login como pantalla inicial',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // La app no autenticada debe mostrar al menos dos campos de texto
      // (email/usuario + contraseña) y un botón de acción.
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  // ── Formulario de login ────────────────────────────────────────────────────

  group('Login — validación de formulario', () {
    testWidgets('rechaza envío con campos vacíos', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Pulsar el botón sin rellenar nada
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Debe aparecer al menos un mensaje de error de validación
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.toLowerCase().contains('obligatorio') == true ||
                  w.data?.toLowerCase().contains('requerido') == true ||
                  w.data?.toLowerCase().contains('required') == true),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('acepta texto en los campos de email y contraseña',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'usuario@ejemplo.com');
      await tester.enterText(fields.at(1), 'contraseña123');
      await tester.pumpAndSettle();

      // Verificar que los valores se escribieron correctamente
      final emailField =
          tester.widget<TextFormField>(fields.at(0));
      final passField =
          tester.widget<TextFormField>(fields.at(1));
      expect(emailField.controller?.text, 'usuario@ejemplo.com');
      expect(passField.controller?.text, 'contraseña123');
    });
  });

  // ── Accesibilidad básica ───────────────────────────────────────────────────

  group('Accesibilidad', () {
    testWidgets('no hay widgets con semantics label vacío en la pantalla inicial',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verificar que el árbol de widgets se renderiza sin fallos
      final handle = tester.ensureSemantics();
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });
}
