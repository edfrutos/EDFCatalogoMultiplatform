import 'dart:typed_data';
import 'dart:ui' as ui;

/// Lado mayor máximo (px) admitido para imágenes subidas desde Flutter Web.
///
/// CanvasKit/Skia puede fallar al decodificar fotos de cámaras réflex o
/// mirrorless sin redimensionar (ej. 6000x4000, 24MP) — ver
/// docs/edfcat-efjdefrutos-infraestructura.md §16.2. Las fotos de móvil
/// habituales (hasta ~4032x3024, 12MP) quedan por debajo de este límite.
const int kMaxWebImageDimension = 4096;

/// Comprueba si [bytes] corresponde a una imagen dentro del límite de
/// resolución soportado por el decodificador de Flutter Web.
///
/// Devuelve `null` si la imagen es válida, o un mensaje de error listo para
/// mostrar al usuario si debe rechazarse.
Future<String?> checkWebImageResolution(
  Uint8List bytes, {
  String? fileName,
  int maxDimension = kMaxWebImageDimension,
}) async {
  final label = fileName != null ? '"$fileName"' : 'La imagen';
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    codec.dispose();

    if (width > maxDimension || height > maxDimension) {
      return '$label es demasiado grande (${width}x$height px). '
          'El límite soportado en la web es ${maxDimension}x$maxDimension px: '
          'redimensiónala antes de subirla.';
    }
    return null;
  } catch (_) {
    return '$label no se pudo procesar (resolución o formato no soportados en la web).';
  }
}
