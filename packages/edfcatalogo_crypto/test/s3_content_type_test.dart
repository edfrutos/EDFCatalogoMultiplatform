import 'package:edfcatalogo_crypto/s3_content_type.dart';
import 'package:test/test.dart';

void main() {
  test('PDF e imágenes por extensión, no por lo que mande el browser', () {
    expect(S3ContentType.fromFileName('doc.PDF'), 'application/pdf');
    expect(S3ContentType.fromFileName('foto.jpg'), 'image/jpeg');
    expect(S3ContentType.fromFileName('foto.jpeg'), 'image/jpeg');
    expect(S3ContentType.fromFileName('users/x/file.png'), 'image/png');
  });

  test('desconocido es octet-stream', () {
    expect(S3ContentType.fromFileName('a.bin'), S3ContentType.octetStream);
    expect(S3ContentType.fromFileName('sin-ext'), S3ContentType.octetStream);
  });

  test('isGeneric cubre ausente, vacío y octet-stream con charset', () {
    expect(S3ContentType.isGeneric(null), isTrue);
    expect(S3ContentType.isGeneric(''), isTrue);
    expect(S3ContentType.isGeneric('application/octet-stream'), isTrue);
    expect(
      S3ContentType.isGeneric('application/octet-stream; charset=binary'),
      isTrue,
    );
    expect(S3ContentType.isGeneric('application/pdf'), isFalse);
  });
}
