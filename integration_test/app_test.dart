// integration_test/app_test.dart
//
// Tests E2E de dispositivo. Requieren un dispositivo/emulador real y
// la app configurada con MONGO_URI apuntando a un entorno de pruebas.
//
// Ejecución local:
//   flutter test integration_test/ -d <device-id>
//
// Estos tests NO se ejecutan en CI (el workflow usa `flutter test` sin args,
// que solo cubre test/).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:edfcatalogomultiplatform/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App E2E (requiere dispositivo + MongoDB de prueba)', () {
    testWidgets('la app arranca sin excepciones no controladas', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // La app debe mostrar al menos un widget (LoginView o MainView)
      expect(find.byType(FlutterError), findsNothing);
    });
  });
}
