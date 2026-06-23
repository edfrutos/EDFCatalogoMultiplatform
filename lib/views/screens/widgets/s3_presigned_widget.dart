import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/s3_service.dart';

/// Widget genérico que pre-firma una URL de S3 y la pasa al builder.
/// Útil para documentos, multimedia y cualquier archivo S3.
///
/// Ejemplo de uso:
/// ```dart
/// S3PresignedBuilder(
///   rawUrl: myS3Url,
///   builder: (context, signedUrl) => Text(signedUrl),
/// )
/// ```
class S3PresignedBuilder extends StatefulWidget {
  final String rawUrl;
  final Widget Function(BuildContext context, String signedUrl) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const S3PresignedBuilder({
    super.key,
    required this.rawUrl,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  State<S3PresignedBuilder> createState() => _S3PresignedBuilderState();
}

class _S3PresignedBuilderState extends State<S3PresignedBuilder> {
  late Future<String> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = _fetchSignedUrl(widget.rawUrl);
  }

  @override
  void didUpdateWidget(S3PresignedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl) {
      _signedUrlFuture = _fetchSignedUrl(widget.rawUrl);
    }
  }

  Future<String> _fetchSignedUrl(String rawUrl) async {
    // S3Service cachea internamente la URL firmada, por lo que
    // llamadas repetidas para la misma key son instantáneas.
    final uri = await S3Service().getPresignedUrl(key: rawUrl);
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ??
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return widget.errorWidget ??
              const Icon(Icons.broken_image, color: Colors.grey);
        }
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

/// Widget de imagen S3 con pre-firma automática y caché.
/// Reemplaza directamente a CachedNetworkImage/NetworkImage para URLs de S3.
///
/// Ejemplo de uso:
/// ```dart
/// S3Image(
///   rawUrl: myS3ImageUrl,
///   width: 200,
///   height: 150,
///   fit: BoxFit.cover,
/// )
/// ```
class S3Image extends StatelessWidget {
  final String rawUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const S3Image({
    super.key,
    required this.rawUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return S3PresignedBuilder(
      rawUrl: rawUrl,
      loadingWidget:
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget:
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
      builder: (context, signedUrl) {
        final image = CachedNetworkImage(
          imageUrl: signedUrl,
          // cacheKey usa la S3 key original (sin firma ni timestamp) para que
          // CachedNetworkImage reutilice la imagen del disco aunque la URL firmada
          // haya cambiado entre sesiones.
          cacheKey: rawUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: (_, _) =>
              placeholder ??
              Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (_, _, _) =>
              errorWidget ??
              Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
        );

        if (borderRadius != null) {
          return ClipRRect(borderRadius: borderRadius!, child: image);
        }
        return image;
      },
    );
  }
}

/// ImageProvider pre-firmado para usar en CircleAvatar u otros widgets
/// que requieren un ImageProvider en lugar de un Widget.
///
/// Ejemplo de uso con FutureBuilder:
/// ```dart
/// FutureBuilder<ImageProvider>(
///   future: S3ImageProvider.fromUrl(rawUrl),
///   builder: (context, snap) => CircleAvatar(
///     backgroundImage: snap.data,
///   ),
/// )
/// ```
class S3ImageProvider {
  static Future<ImageProvider> fromUrl(String rawUrl) async {
    final uri = await S3Service().getPresignedUrl(key: rawUrl);
    return CachedNetworkImageProvider(
      uri.toString(),
      // cacheKey estable: no cambia con la firma, reutiliza la caché de disco
      cacheKey: rawUrl,
    );
  }
}
