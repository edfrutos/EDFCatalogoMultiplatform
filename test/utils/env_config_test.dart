// Tests unitarios de env_config.dart
//
// Verifica que los getters de EnvConfig delegan correctamente en
// getEnvVariable y aplican los valores por defecto esperados.

import 'package:flutter_test/flutter_test.dart';

import 'package:edfcatalogomultiplatform/utils/env_config.dart';
import 'package:edfcatalogomultiplatform/utils/env_loader.dart';

void main() {
  setUp(() {
    globalEnvMap.clear();
  });

  group('EnvConfig — MongoDB', () {
    test('mongoUri devuelve valor del mapa', () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://u:p@host/db';
      expect(EnvConfig.mongoUri, 'mongodb+srv://u:p@host/db');
    });

    test('mongoUri devuelve cadena vacía si no está configurado', () {
      expect(EnvConfig.mongoUri, '');
    });

    test('mongoDb devuelve valor del mapa', () {
      globalEnvMap['MONGO_DB'] = 'catalogo_prod';
      expect(EnvConfig.mongoDb, 'catalogo_prod');
    });
  });

  group('EnvConfig — AWS S3', () {
    test('awsRegion devuelve eu-central-1 por defecto', () {
      expect(EnvConfig.awsRegion, 'eu-central-1');
    });

    test('awsRegion devuelve valor del mapa si está configurado', () {
      globalEnvMap['AWS_REGION'] = 'us-east-1';
      expect(EnvConfig.awsRegion, 'us-east-1');
    });

    test('useS3 es false cuando USE_S3 no está configurado', () {
      expect(EnvConfig.useS3, isFalse);
    });

    test('useS3 es true cuando USE_S3=true', () {
      globalEnvMap['USE_S3'] = 'true';
      expect(EnvConfig.useS3, isTrue);
    });

    test('useS3 es false para cualquier valor que no sea "true"', () {
      globalEnvMap['USE_S3'] = 'yes';
      expect(EnvConfig.useS3, isFalse);
    });

    test('bucketName prefiere S3_BUCKET_NAME sobre BUCKET_NAME', () {
      globalEnvMap['S3_BUCKET_NAME'] = 'bucket-principal';
      globalEnvMap['BUCKET_NAME'] = 'bucket-alternativo';
      expect(EnvConfig.bucketName, 'bucket-principal');
    });

    test('bucketName usa BUCKET_NAME cuando S3_BUCKET_NAME está vacío', () {
      globalEnvMap['BUCKET_NAME'] = 'bucket-alternativo';
      expect(EnvConfig.bucketName, 'bucket-alternativo');
    });
  });

  group('EnvConfig — Brevo', () {
    test('brevoSmtpServer devuelve smtp-relay.brevo.com por defecto', () {
      expect(EnvConfig.brevoSmtpServer, 'smtp-relay.brevo.com');
    });

    test('brevoSmtpPort devuelve 587 por defecto', () {
      expect(EnvConfig.brevoSmtpPort, 587);
    });

    test('brevoSmtpPort parsea el valor del mapa', () {
      globalEnvMap['BREVO_SMTP_PORT'] = '465';
      expect(EnvConfig.brevoSmtpPort, 465);
    });

    test('brevoSmtpPort devuelve 587 si el valor no es numérico', () {
      globalEnvMap['BREVO_SMTP_PORT'] = 'no-un-numero';
      expect(EnvConfig.brevoSmtpPort, 587);
    });
  });

  group('EnvConfig — validate()', () {
    test('validate() falla cuando mongoUri y mongoDb están vacíos', () {
      expect(EnvConfig.validate(), isFalse);
    });

    test('validate() falla cuando solo mongoUri está configurado', () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://u:p@host/db';
      expect(EnvConfig.validate(), isFalse);
    });

    test('validate() pasa cuando mongoUri y mongoDb están configurados', () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://u:p@host/db';
      globalEnvMap['MONGO_DB'] = 'catalogo';
      expect(EnvConfig.validate(), isTrue);
    });

    test('validate() falla cuando useS3=true pero faltan credenciales AWS', () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://u:p@host/db';
      globalEnvMap['MONGO_DB'] = 'catalogo';
      globalEnvMap['USE_S3'] = 'true';
      // AWS keys ausentes
      expect(EnvConfig.validate(), isFalse);
    });

    test('validate() pasa cuando useS3=true con credenciales AWS completas',
        () {
      globalEnvMap['MONGO_URI'] = 'mongodb+srv://u:p@host/db';
      globalEnvMap['MONGO_DB'] = 'catalogo';
      globalEnvMap['USE_S3'] = 'true';
      globalEnvMap['AWS_ACCESS_KEY_ID'] = 'AKIAIOSFODNN7EXAMPLE';
      globalEnvMap['AWS_SECRET_ACCESS_KEY'] = 'wJalrXUtnFEMI/K7MDENG';
      expect(EnvConfig.validate(), isTrue);
    });
  });
}
