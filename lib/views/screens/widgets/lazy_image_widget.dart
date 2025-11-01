import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget para cargar imágenes de forma perezosa (lazy loading)
/// Solo carga la imagen cuando está visible en la pantalla
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
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Verificar visibilidad después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;
    
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // Verificar si el widget está en el viewport
    final screenHeight = MediaQuery.of(context).size.height;
    final isInViewport = position.dy + size.height >= 0 && position.dy <= screenHeight;

    if (isInViewport && !_isVisible) {
      setState(() {
        _isVisible = true;
      });
    } else if (!isInViewport && _isVisible) {
      // Opcional: descargar imagen cuando sale del viewport para ahorrar memoria
      // setState(() {
      //   _isVisible = false;
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Verificar visibilidad cuando se hace scroll
        Future.microtask(() => _checkVisibility());
        return false;
      },
      child: SizedBox(
        key: _key,
        width: widget.width,
        height: widget.height,
        child: _isVisible
            ? CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: widget.fit,
                placeholder: (context, url) =>
                    widget.placeholder ??
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    widget.errorWidget ??
                    const Icon(Icons.error_outline, color: Colors.red),
                memCacheWidth: widget.width?.toInt(),
                memCacheHeight: widget.height?.toInt(),
              )
            : (widget.placeholder ??
                Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.grey),
                  ),
                )),
      ),
    );
  }
}

