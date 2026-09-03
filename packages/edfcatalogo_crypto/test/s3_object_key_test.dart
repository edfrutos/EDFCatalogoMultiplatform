import 'package:edfcatalogo_crypto/s3_object_key.dart';
import 'package:test/test.dart';

void main() {
  test('cleanId extrae ObjectId y deja ids limpios', () {
    expect(S3ObjectKey.cleanId('ObjectId("abc123")'), 'abc123');
    expect(S3ObjectKey.cleanId('abc123'), 'abc123');
  });

  test('normalizeKind unifica plurales web con el enum nativo', () {
    expect(S3ObjectKey.normalizeKind('images'), 'image');
    expect(S3ObjectKey.normalizeKind('documents'), 'document');
    expect(S3ObjectKey.normalizeKind('image'), 'image');
    expect(S3ObjectKey.normalizeKind('uploads'), 'other');
    expect(S3ObjectKey.normalizeKind('../etc'), 'other');
  });

  test('build coincide con el layout nativo histórico', () {
    expect(
      S3ObjectKey.build(
        userId: 'u1',
        catalogId: 'c1',
        kind: 'image',
        originalFileName: 'foto.JPG',
        uuid: 'uuid-1',
      ),
      'users/u1/catalogs/c1/image/uuid-1.jpg',
    );
  });

  test('prefix es la carpeta que la API pone delante del uuid', () {
    expect(
      S3ObjectKey.prefix(
        userId: 'ObjectId("u1")',
        catalogId: 'c1',
        kind: 'documents',
      ),
      'users/u1/catalogs/c1/document',
    );
  });

  test('extensionOf minúsculas y vacía si no hay', () {
    expect(S3ObjectKey.extensionOf('a.PDF'), '.pdf');
    expect(S3ObjectKey.extensionOf('sin-ext'), '');
    expect(S3ObjectKey.extensionOf('ruta/x.PNG'), '.png');
  });
}
