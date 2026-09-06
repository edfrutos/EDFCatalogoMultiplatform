// Test de la cola de guardado de CatalogDetailViewModel
//
// Reproduce la condición de carrera original: dos guardados disparados
// casi a la vez, donde la respuesta del primero llega DESPUÉS que la del
// segundo. Sin la cola de _persistCatalogChanges, el snapshot más antiguo
// pisaba al más reciente. Con la cola, deben ejecutarse en orden.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:edfcatalogomultiplatform/models/catalog.dart';
import 'package:edfcatalogomultiplatform/services/mongo_service.dart';
import 'package:edfcatalogomultiplatform/viewmodels/catalog_detail_viewmodel.dart';

class MockMongoService extends Mock implements MongoService {}

class FakeCatalog extends Fake implements Catalog {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCatalog());
  });

  late MockMongoService mongo;

  Catalog buildCatalog({List<CatalogRow> rows = const []}) => Catalog(
        id: 'catalog-1',
        name: 'Catálogo de prueba',
        description: '',
        userId: 'user-1',
        columns: const ['Nombre'],
        rows: rows,
        thumbnailUrl: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  setUp(() {
    mongo = MockMongoService();
  });

  test(
      'dos guardados casi simultáneos no se pisan aunque el primero '
      'complete después que el segundo (condición de carrera original)',
      () async {
    // Captura cada llamada real a Mongo, en el orden en que EL BACKEND
    // las recibe (no en el orden en que el ViewModel las disparó).
    final received = <Catalog>[];

    // La respuesta a la 1ª llamada tarda más que la 2ª — invierte el orden
    // de llegada, que es justo lo que provocaba el bug original.
    var callCount = 0;
    when(() => mongo.updateCatalogFromObject(any())).thenAnswer((inv) async {
      callCount++;
      final catalog = inv.positionalArguments[0] as Catalog;
      final isFirstCall = callCount == 1;
      // 1ª llamada: retraso largo. 2ª llamada: retraso corto.
      await Future.delayed(
        isFirstCall ? const Duration(milliseconds: 50) : const Duration(milliseconds: 5),
      );
      received.add(catalog);
      return true;
    });

    final vm = CatalogDetailViewModel(
      catalog: buildCatalog(),
      mongoService: mongo,
    );

    // Disparamos dos "guardados" casi a la vez, igual que ocurre cuando
    // el usuario añade dos filas (con ficheros subidos) muy seguidas.
    vm.addRow({'Nombre': 'Fila A'}, RowFiles());
    vm.addRow({'Nombre': 'Fila B'}, RowFiles());

    // Esperamos a que ambos guardados encolados terminen.
    await Future.delayed(const Duration(milliseconds: 100));

    // Con la cola: deben haberse recibido 2 escrituras, EN ORDEN, y la
    // última (la que realmente queda en la BD) debe contener ambas filas.
    expect(received.length, 2);
    expect(received.last.rows.map((r) => r.data['Nombre']),
        containsAll(['Fila A', 'Fila B']));

    // Sin la cola, la escritura con snapshot antiguo (Fila A sola)
    // habría llegado la última y sobrescrito la de las dos filas.
    expect(received.last.rows.length, 2,
        reason:
            'La última escritura en Mongo debe contener ambas filas; si '
            'solo tiene 1, la condición de carrera ha vuelto a producirse.');
  });
}
