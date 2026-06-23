import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/s3_service.dart';

/// Widget para cargar imágenes de forma perezosa (lazy loading) con
/// pre-firma automática de URLs de Amazon S3 (bucket privado).
/// Admite cualquier formato soportado por CachedNetworkImage:
/// JPEG, PNG, WebP, GIF, BMP, WBMP.
class LazyImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LazyImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LazyImageWidget> createState() => _LazyImageWidgetState();
}

class _LazyImageWidgetState extends State<LazyImageWidget> {
  bool _isVisible = false;
  String? _presignedUrl;
  final _key = GlobalKey();

  // ¿Es una URL de S3 privado que necesita pre-firma?
  bool get _needsPresign =>
      widget.imageUrl.contains('amazonaws.com') &&
      !widget.imageUrl.contains('X-Amz-Signature');

  // URL efectiva: pre-firmada si se obtuvo, o la original (p.ej. URL pública)
  String get _effectiveUrl => _presignedUrl ?? widget.imageUrl;

  @override
  void initState() {
    super.initState();
    if (_needsPresign) {
      _presignUrl();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  Future<void> _presignUrl() async {
    try {
      final signed = await S3Service().getPresignedUrl(key: widget.imageUrl);
      if (!mounted) return;
      setState(() {
        _presignedUrl = signed.toString();
      });
    } catch (e) {
      print('❌ LazyImageWidget: error pre-firmando URL: $e');
      // Continúa con la URL original; CachedNetworkImage mostrará errorWidget
      if (mounted) setState(() => _presignedUrl = widget.imageUrl);
    }
  }

  void _checkVisibility() {
    if (!mounted) return;

    final RenderBox? renderBox =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final isInViewport =
        position.dy + size.height >= 0 && position.dy <= screenHeight;

    if (isInViewport && !_isVisible) {
      setState(() => _isVisible = true);
    }
  }

  Widget get _placeholderWidget =>
      widget.placeholder ??
      Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
      );

  Widget get _errorWidgetFallback =>
      widget.errorWidget ??
      Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Esperar pre-firma antes de intentar cargar (evita 403)
    final bool ready = !_needsPresign || _presignedUrl != null;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        Future.microtask(() => _checkVisibility());
        return false;
      },
      child: SizedBox(
        key: _key,
        width: widget.width,
        height: widget.height,
        child: ready && _isVisible
            ? CachedNetworkImage(
                imageUrl: _effectiveUrl,
                fit: widget.fit,
                width: widget.width,
                height: widget.height,
                placeholder: (context, url) => _placeholderWidget,
                errorWidget: (context, url, error) {
                  print('❌ LazyImageWidget: error cargando imagen: $error');
                  print('   URL: ${_effectiveUrl.substring(0, _effectiveUrl.length > 80 ? 80 : _effectiveUrl.length)}...');
                  return _errorWidgetFallback;
                },
                memCacheWidth: widget.width?.toInt(),
                memCacheHeight: widget.height?.toInt(),
              )
            : _placeholderWidget,
      ),
    );
  }
}
