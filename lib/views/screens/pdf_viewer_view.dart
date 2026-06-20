import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Visor de PDF completo con navegación, zoom y compartir.
///
/// Equivalente Flutter de PDFViewerView.swift (EDFCatalogoSwift).
///
/// Uso:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => PdfViewerView(url: fileUrl, fileName: 'documento.pdf'),
/// ));
/// ```
class PdfViewerView extends StatefulWidget {
  final String url;
  final String fileName;

  const PdfViewerView({super.key, required this.url, required this.fileName});

  @override
  State<PdfViewerView> createState() => _PdfViewerViewState();
}

class _PdfViewerViewState extends State<PdfViewerView> {
  final PdfViewerController _controller = PdfViewerController();

  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  bool _isLoading = true;
  String? _errorMessage;

  static const double _zoomStep = 0.25;
  static const double _zoomMin = 0.5;
  static const double _zoomMax = 3.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _controller.previousPage();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _controller.nextPage();
    }
  }

  void _zoomIn() {
    final newZoom = (_zoomLevel + _zoomStep).clamp(_zoomMin, _zoomMax);
    setState(() => _zoomLevel = newZoom);
    _controller.zoomLevel = newZoom;
  }

  void _zoomOut() {
    final newZoom = (_zoomLevel - _zoomStep).clamp(_zoomMin, _zoomMax);
    setState(() => _zoomLevel = newZoom);
    _controller.zoomLevel = newZoom;
  }

  void _resetZoom() {
    setState(() => _zoomLevel = 1.0);
    _controller.zoomLevel = 1.0;
  }

  Future<void> _share() async {
    try {
      // En web y plataformas sin acceso a ficheros, compartir la URL directamente
      if (kIsWeb) {
        await SharePlus.instance.share(ShareParams(text: widget.url));
        return;
      }
      // En móvil/escritorio compartir como archivo (si la URL es local)
      if (widget.url.startsWith('/') || widget.url.startsWith('file://')) {
        final file = XFile(widget.url.replaceFirst('file://', ''));
        await SharePlus.instance.share(ShareParams(files: [file]));
      } else {
        // URL remota: compartir el enlace
        await SharePlus.instance.share(
          ShareParams(
            text: '${widget.fileName}\n${widget.url}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── PDF viewer ──────────────────────────────────────────────────
          Expanded(
            child: _errorMessage != null
                ? _buildError()
                : Stack(
                    children: [
                      SfPdfViewer.network(
                        widget.url,
                        controller: _controller,
                        enableDoubleTapZooming: true,
                        enableTextSelection: true,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        onDocumentLoaded: (details) {
                          setState(() {
                            _totalPages = details.document.pages.count;
                            _isLoading = false;
                          });
                        },
                        onDocumentLoadFailed: (details) {
                          setState(() {
                            _errorMessage = details.description;
                            _isLoading = false;
                          });
                        },
                        onPageChanged: (details) {
                          setState(() => _currentPage = details.newPageNumber);
                        },
                        onZoomLevelChanged: (details) {
                          setState(() => _zoomLevel = details.newZoomLevel);
                        },
                      ),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),

          // ── Barra de controles ───────────────────────────────────────────
          if (!_isLoading && _errorMessage == null) _buildControlBar(theme),
        ],
      ),
    );
  }

  Widget _buildControlBar(ThemeData theme) {
    final canPrev = _currentPage > 1;
    final canNext = _currentPage < _totalPages;
    final canZoomIn = _zoomLevel < _zoomMax;
    final canZoomOut = _zoomLevel > _zoomMin;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Navegación de páginas
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Página anterior',
            onPressed: canPrev ? _previousPage : null,
          ),
          Text(
            _totalPages > 0
                ? 'Pág. $_currentPage / $_totalPages'
                : 'Cargando…',
            style: theme.textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Página siguiente',
            onPressed: canNext ? _nextPage : null,
          ),

          const VerticalDivider(width: 24, indent: 8, endIndent: 8),

          // Zoom
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Reducir zoom',
            onPressed: canZoomOut ? _zoomOut : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${(_zoomLevel * 100).round()}%',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Aumentar zoom',
            onPressed: canZoomIn ? _zoomIn : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restablecer zoom',
            onPressed: _zoomLevel != 1.0 ? _resetZoom : null,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar el PDF',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
