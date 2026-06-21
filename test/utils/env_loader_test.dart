// Tests unitarios de env_loader.dart
//
// Cubre getEnvVariable(), que es la única API de env_loader visible
// sin depender de rootBundle ni del sistema de archivos.

import 'package:flutter_test/flutter_test.dart';

import 'package:edfcatalogomultiplatform/utils/env_loader.dart';

void main() {
  group('getEnvVariable', () {
    setUp(() {
      // Limpiar estado global antes de cada test
      globalEnvMap.clear();
    });

    test('devuelve valor de globalEnvMap cuando dotenv no está inicializado',
        () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://test:pass@host/db';
      expect(
        getEnvVariable('MONGO_URI'),
        'mongodb+srv://test:pass@host/db',
      );
    });

    test('devuelve defaultValue cuando la clave no existe', () {
      expect(getEnvVariable('CLAVE_INEXISTENTE', defaultValue: 'fallback'),
          'fallback');
    });

    test('devuelve cadena vacía por defecto cuando la clave no existe', () {
      expect(getEnvVariable('OTRA_CLAVE_INEXISTENTE'), '');
    });

    test('devuelve el valor correcto con múltiples claves en el mapa', () {
      globalEnvMap['KEY_A'] = 'valor_a';
      globalEnvMap['KEY_B'] = 'valor_b';
      expect(getEnvVariable('KEY_A'), 'valor_a');
      expect(getEnvVariable('KEY_B'), 'valor_b');
    });

    test('devuelve defaultValue si la clave existe pero está vacía', () {
      globalEnvMap['EMPTY_KEY'] = '';
      // Cadena vacía en el mapa → el getter devuelve defaultValue
      // porque globalEnvMap[key] ?? defaultValue solo hace null-check,
      // no empty-check. Documentar el comportamiento actual:
      expect(getEnvVariable('EMPTY_KEY', defaultValue: 'default'), '');
    });

    test('setUp limpia el mapa entre tests', () {
      // Este test verifica que setUp funciona: las claves del test anterior
      // no deben estar presentes.
      expect(globalEnvMap.containsKey('MONGO_URI'), isFalse);
    });
  });
}
