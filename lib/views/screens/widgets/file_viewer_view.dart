import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:convert' show utf8, latin1;
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../models/file_type.dart';

/// Visualizador completo de archivos con soporte para PDF, video, audio e imágenes
class FileViewerView extends StatefulWidget {
  final String url;
  final String fileName;

  const FileViewerView({super.key, required this.url, required this.fileName});

  @override
  State<FileViewerView> createState() => _FileViewerViewState();
}

class _FileViewerViewState extends State<FileViewerView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoadingVideo = false;
  String? _videoError;

  // Para archivos de texto
  String? _textContent;
  bool _isLoadingText = false;
  String? _textError;

  // Para WebView de YouTube
  WebViewController? _webViewController;
  bool _hasLoadedInitialContent = false;
  String? _currentVideoId;

  FileType _getFileType(String url) {
    final lower = url.toLowerCase();
    final fileNameLower = widget.fileName.toLowerCase();

    // Detectar URLs de streaming (YouTube, Vimeo, etc.) PRIMERO
    if (_isStreamingVideo(url)) {
      return FileType.multimedia;
    }

    // Si la URL contiene "/document/" en la ruta, es un documento (independientemente de la extensión)
    // Esto permite que archivos .md, .csv, .txt, etc. que fueron subidos como documentos se reconozcan como tal
    if (lower.contains('/document/')) {
      return FileType.document;
    }

    // Detectar archivos de texto plano y formatos de texto
    if (lower.contains('.txt') ||
        fileNameLower.endsWith('.txt') ||
        lower.contains('.md') ||
        lower.contains('.markdown') ||
        fileNameLower.endsWith('.md') ||
        fileNameLower.endsWith('.markdown') ||
        lower.contains('.rtf') ||
        fileNameLower.endsWith('.rtf') ||
        lower.contains('.json') ||
        fileNameLower.endsWith('.json') ||
        lower.contains('.xml') ||
        fileNameLower.endsWith('.xml') ||
        lower.contains('.csv') ||
        fileNameLower.endsWith('.csv') ||
        lower.contains('.log') ||
        fileNameLower.endsWith('.log')) {
      return FileType.text;
    }

    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp') ||
        lower.contains('.bmp')) {
      return FileType.image;
    } else if (lower.contains('.pdf') ||
        fileNameLower.endsWith('.pdf') ||
        lower.contains('.doc') ||
        fileNameLower.endsWith('.doc') ||
        lower.contains('.docx') ||
        fileNameLower.endsWith('.docx')) {
      // Documentos: PDF y documentos de Word
      return FileType.document;
    } else if (lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.webm') ||
        lower.contains('.mkv')) {
      return FileType.multimedia;
    } else if (lower.contains('.mp3') ||
        lower.contains('.wav') ||
        lower.contains('.ogg') ||
        lower.contains('.aac')) {
      return FileType.multimedia; // Audio también es multimedia
    }
    return FileType.other;
  }

  bool _isMarkdown(String url) {
    final lower = url.toLowerCase();
    final fileNameLower = widget.fileName.toLowerCase();
    return lower.contains('.md') ||
        lower.contains('.markdown') ||
        fileNameLower.endsWith('.md') ||
        fileNameLower.endsWith('.markdown');
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.webm') ||
        lower.contains('.mkv');
  }

  bool _isAudio(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp3') ||
        lower.contains('.wav') ||
        lower.contains('.ogg') ||
        lower.contains('.aac');
  }

  bool _isStreamingVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('vimeo.com') ||
        lower.contains('dailymotion.com') ||
        lower.contains('twitch.tv') ||
        lower.contains('facebook.com/watch') ||
        lower.contains('instagram.com/p/') ||
        lower.contains('tiktok.com') ||
        lower.contains('streamable.com') ||
        lower.contains('embed') ||
        lower.contains('player');
  }

  String? _extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtube.com/shorts/VIDEO_ID
    if (uri.host.contains('youtube.com')) {
      final path = uri.path;
      if (path.startsWith('/shorts/')) {
        final videoId = path.substring('/shorts/'.length).split('?')[0];
        if (videoId.isNotEmpty) {
          return videoId;
        }
      }
      // youtube.com/watch?v=VIDEO_ID
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
    }
    // youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final path = uri.path;
      if (path.isNotEmpty && path.startsWith('/')) {
        return path.substring(1).split('?')[0];
      }
    }
    return null;
  }

  String _getYouTubeEmbedHtml(String videoId) {
    // Generar HTML completo con iframe embebido (similar a la app Swift)
    // Usar más parámetros para asegurar que el embed funcione correctamente
    // Intentar primero con youtube.com (más permisivo), luego con youtube-nocookie.com
    final embedUrl =
        'https://www.youtube-nocookie.com/embed/$videoId?'
        'rel=0&'
        'modestbranding=1&'
        'playsinline=1&'
        'enablejsapi=1&'
        'autoplay=0&'
        'controls=1&'
        'fs=1&'
        'iv_load_policy=3&'
        'origin=https://www.youtube-nocookie.com';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
    }
    .wrapper {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: 0;
      display: block;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <iframe 
      id="youtube-player"
      src="$embedUrl" 
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
      allowfullscreen
      webkitallowfullscreen
      mozallowfullscreen
      oallowfullscreen
      msallowfullscreen>
    </iframe>
  </div>
  <script>
    // Asegurar que el iframe mantiene el tamaño
    window.addEventListener('resize', function() {
      var iframe = document.getElementById('youtube-player');
      if (iframe) {
        iframe.style.width = '100%';
        iframe.style.height = '100%';
      }
    });
  </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    final fileType = _getFileType(widget.url);

    if (fileType == FileType.multimedia && !_isStreamingVideo(widget.url)) {
      _initializeVideo();
    } else if (fileType == FileType.text) {
      _loadTextFile();
    } else if (fileType == FileType.document) {
      // Cargar como texto si no es PDF (para .txt, .rtf, etc. que fueron seleccionados como documentos)
      final lower = widget.url.toLowerCase();
      final fileNameLower = widget.fileName.toLowerCase();
      if (!lower.contains('.pdf') && !fileNameLower.endsWith('.pdf')) {
        _loadTextFile();
      }
    }
  }

  Future<void> _loadTextFile() async {
    setState(() {
      _isLoadingText = true;
      _textError = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        // Decodificar explícitamente con UTF-8 para evitar problemas de codificación (mojibake)
        // El paquete http por defecto puede no usar UTF-8 correctamente para caracteres especiales
        String decodedText;
        try {
          // Intentar UTF-8 primero (más común para archivos de texto modernos)
          decodedText = utf8.decode(response.bodyBytes, allowMalformed: false);
          print('✅ Texto decodificado con UTF-8');
        } catch (e) {
          // Si UTF-8 falla estrictamente, intentar con allowMalformed=true
          try {
            decodedText = utf8.decode(response.bodyBytes, allowMalformed: true);
            print(
              '⚠️ UTF-8 decodificado con allowMalformed (algunos caracteres pueden estar incorrectos)',
            );
          } catch (e2) {
            // Si UTF-8 falla completamente, intentar detectar el encoding del Content-Type
            print(
              '⚠️ Error decodificando UTF-8, intentando con otros encodings: $e2',
            );
            try {
              final contentType = response.headers['content-type'] ?? '';
              if (contentType.contains('charset=')) {
                final charset = contentType
                    .split('charset=')[1]
                    .split(';')[0]
                    .trim()
                    .toLowerCase();
                print('📋 Content-Type indica charset: $charset');
                if (charset == 'iso-8859-1' || charset == 'latin1') {
                  decodedText = latin1.decode(response.bodyBytes);
                } else {
                  // Último recurso: usar response.body (que usa el charset por defecto)
                  decodedText = response.body;
                }
              } else {
                // Si no hay charset especificado, intentar UTF-8 con allowMalformed
                // y si falla, usar response.body
                decodedText = utf8.decode(
                  response.bodyBytes,
                  allowMalformed: true,
                );
              }
            } catch (e3) {
              // Último recurso absoluto: usar response.body tal cual
              print(
                '⚠️ Todos los métodos de decodificación fallaron, usando response.body directamente',
              );
              decodedText = response.body;
            }
          }
        }

        setState(() {
          _textContent = decodedText;
          _isLoadingText = false;
        });
      } else {
        throw Exception('Error al cargar archivo: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _textError = e.toString();
        _isLoadingText = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoadingVideo = true;
      _videoError = null;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );

      await _videoPlayerController!.initialize();

      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: false,
            looping: false,
            allowFullScreen: true,
            allowMuting: true,
            allowPlaybackSpeedChanging: true,
            showControls: true,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
          );
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = 'Error al cargar el video: $e';
          _isLoadingVideo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileType = _getFileType(widget.url);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'Abrir en navegador',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context),
            tooltip: 'Descargar',
          ),
        ],
      ),
      body: _buildContent(context, fileType),
    );
  }

  Widget _buildContent(BuildContext context, FileType fileType) {
    switch (fileType) {
      case FileType.image:
        return _buildImageView();
      case FileType.document:
        // Si es PDF, usar el visor de PDF; si no, intentar como texto
        final lower = widget.url.toLowerCase();
        final fileNameLower = widget.fileName.toLowerCase();
        final isPdf = lower.contains('.pdf') || fileNameLower.endsWith('.pdf');
        final isDoc =
            lower.contains('.doc') ||
            fileNameLower.endsWith('.doc') ||
            lower.contains('.docx') ||
            fileNameLower.endsWith('.docx');

        if (isPdf) {
          return _buildPdfView();
        } else if (isDoc) {
          // Archivos .doc y .docx no se pueden visualizar directamente
          // Se mostrará el mensaje en _buildTextView cuando se detecte
          if (_textContent == null && !_isLoadingText) {
            _loadTextFile();
          }
          return _buildTextView();
        } else {
          // Para .txt, .rtf, etc., cargar como texto
          // Esto permite visualizar archivos de texto que fueron seleccionados como "documento"
          if (_textContent == null && !_isLoadingText) {
            _loadTextFile();
          }
          return _buildTextView();
        }
      case FileType.text:
        return _buildTextView();
      case FileType.multimedia:
        if (_isStreamingVideo(widget.url)) {
          return _buildStreamingVideoView();
        } else if (_isVideo(widget.url)) {
          return _buildVideoView();
        } else if (_isAudio(widget.url)) {
          return _buildAudioView();
        } else {
          return _buildFallbackView(fileType);
        }
      case FileType.other:
        return _buildFallbackView(fileType);
    }
  }

  Widget _buildTextView() {
    if (_isLoadingText) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando archivo de texto...'),
          ],
        ),
      );
    }

    if (_textError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el archivo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _textError!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Abrir en navegador'),
            ),
          ],
        ),
      );
    }

    if (_textContent == null) {
      return const Center(child: Text('No hay contenido para mostrar'));
    }

    // Detectar tipo de archivo de texto
    final lower = widget.url.toLowerCase();
    final fileNameLower = widget.fileName.toLowerCase();
    final isMarkdown = _isMarkdown(widget.url);
    final isRtf = lower.contains('.rtf') || fileNameLower.endsWith('.rtf');
    final isDoc =
        lower.contains('.doc') ||
        fileNameLower.endsWith('.doc') ||
        lower.contains('.docx') ||
        fileNameLower.endsWith('.docx');

    print(
      '📄 Renderizando texto: URL=${widget.url}, fileName=${widget.fileName}, isMarkdown=$isMarkdown, isRtf=$isRtf, isDoc=$isDoc, contentLength=${_textContent?.length}',
    );

    // Archivos .doc y .docx no se pueden visualizar directamente (formato binario)
    if (isDoc) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Archivo de Word',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Los archivos .doc y .docx no se pueden visualizar directamente en la app. Puedes descargarlo o abrirlo en una aplicación externa.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _downloadFile(context),
                          icon: const Icon(Icons.download),
                          label: const Text('Descargar'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(widget.url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Abrir externamente'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Renderizar Markdown con formato
    if (isMarkdown) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(
            data: _textContent!,
            // Desactivar selectable para evitar el error conocido de flutter_markdown
            // El error ocurre cuando se intenta seleccionar texto en MarkdownBody con selectable: true
            selectable: false,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 16, height: 1.6),
              h1: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              h2: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              h3: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              h4: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              listBullet: const TextStyle(fontSize: 16),
              listIndent: 24.0,
              blockquote: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
                backgroundColor: Colors.grey[100],
              ),
              blockquoteDecoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  left: BorderSide(color: Colors.grey[400]!, width: 4),
                ),
              ),
              code: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                backgroundColor: Colors.grey[200],
                color: Colors.purple[900],
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              codeblockPadding: const EdgeInsets.all(12),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              strong: const TextStyle(fontWeight: FontWeight.bold),
              em: const TextStyle(fontStyle: FontStyle.italic),
              tableHead: const TextStyle(
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.grey,
              ),
              tableBody: const TextStyle(),
              tableBorder: TableBorder.all(color: Colors.grey[300]!),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                launchUrl(Uri.parse(href));
              }
            },
          ),
        ),
      );
    }

    // Texto plano (incluye .txt, .rtf sin formato, .json, .xml, .csv, .log, etc.)
    // Para RTF, intentar mostrar el contenido de texto aunque se pierda el formato
    String displayText = _textContent!;

    // Si es RTF, intentar extraer solo el texto legible (simple: remover algunos códigos RTF comunes)
    if (isRtf) {
      // Eliminar códigos RTF básicos para mostrar el texto legible
      displayText = displayText
          .replaceAll(
            RegExp(r'\\[a-z]+\d*\s?'),
            ' ',
          ) // Códigos RTF como \b1, \par, etc.
          .replaceAll(RegExp(r'\{[^}]*\}'), '') // Grupos RTF
          .replaceAll(RegExp(r'\s+'), ' ') // Espacios múltiples
          .trim();

      if (displayText.isEmpty || displayText.length < 10) {
        // Si después de limpiar no queda contenido legible, mostrar mensaje
        return SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Archivo RTF',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'No se pudo extraer el texto del archivo RTF. Puedes descargarlo o abrirlo en una aplicación externa.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _downloadFile(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Descargar'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(widget.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Abrir externamente'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    // Usar fuente monospace para archivos de código/datos, pero fuente normal para texto
    final useMonospace =
        lower.contains('.json') ||
        lower.contains('.xml') ||
        lower.contains('.csv') ||
        lower.contains('.log') ||
        lower.contains('.txt');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: SelectableText(
            displayText,
            style: TextStyle(
              fontFamily: useMonospace ? 'monospace' : null,
              fontSize: useMonospace ? 14 : 16,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageView() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error al cargar la imagen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(widget.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Abrir en navegador'),
                ),
              ],
            ),
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return SfPdfViewer.network(
      widget.url,
      onDocumentLoadFailed: (details) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar PDF: ${details.error}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      enableDoubleTapZooming: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableTextSelection: true,
    );
  }

  Widget _buildVideoView() {
    if (_isLoadingVideo) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando video...'),
          ],
        ),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el video',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _videoError!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Abrir en navegador'),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const Center(child: Text('Inicializando reproductor...'));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  Widget _buildStreamingVideoView() {
    final isYouTube =
        widget.url.toLowerCase().contains('youtube.com') ||
        widget.url.toLowerCase().contains('youtu.be');
    final videoId = isYouTube ? _extractYouTubeVideoId(widget.url) : null;

    // En Linux, WebView no está soportado, usar url_launcher para abrir en navegador externo
    final isLinux = !kIsWeb && Platform.isLinux;
    if (isLinux && isYouTube) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Reproducir video en navegador',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'En Linux, los videos de YouTube se abren en tu navegador predeterminado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(widget.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo abrir el video'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Abrir en navegador'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si el videoId cambió o el WebViewController no está inicializado, reinicializar
    if (isYouTube && videoId != null) {
      if (_webViewController == null || _currentVideoId != videoId) {
        print(
          '🔄 Inicializando/reinicializando WebView para video: $videoId (anterior: $_currentVideoId)',
        );

        // Resetear el flag de carga inicial si cambió el video
        if (_currentVideoId != videoId) {
          _hasLoadedInitialContent = false;
          _currentVideoId = videoId;
        }

        try {
          _webViewController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (NavigationRequest request) {
                  // Si es el main frame
                  if (request.isMainFrame) {
                    // Permitir solo la carga inicial del HTML local
                    if (!_hasLoadedInitialContent) {
                      // Permitir la primera navegación (puede ser cualquier cosa de la carga inicial)
                      _hasLoadedInitialContent = true;
                      print(
                        '✅ Permitida navegación inicial del main frame: ${request.url}',
                      );
                      return NavigationDecision.navigate;
                    }

                    // Después de la carga inicial, bloquear TODAS las navegaciones del main frame
                    // IMPORTANTE: Esto previene que YouTube intente redirigir o abrir ventanas nuevas
                    print(
                      '🚫 BLOQUEADA navegación principal (ya cargado): ${request.url}',
                    );
                    return NavigationDecision.prevent;
                  }

                  // Permitir TODAS las navegaciones dentro del iframe (subframes)
                  // Esto incluye recursos de YouTube dentro del embed que necesita cargar
                  print('✅ Permitida navegación de subframe: ${request.url}');
                  return NavigationDecision.navigate;
                },
                onPageStarted: (String url) {
                  print('🎥 Cargando YouTube WebView: $url');
                },
                onPageFinished: (String url) {
                  print('✅ YouTube WebView cargado: $url');
                  if (mounted) {
                    setState(() {});
                  }
                },
                onWebResourceError: (WebResourceError error) {
                  print('❌ Error en WebView: ${error.description}');
                  print('   Error code: ${error.errorCode}');
                  print('   Error type: ${error.errorType}');
                  print('   URL: ${error.url}');
                },
              ),
            );

          // Cargar HTML con iframe embebido
          // IMPORTANTE: Usar el dominio de YouTube como baseUrl para que el iframe funcione
          _webViewController!.loadHtmlString(
            _getYouTubeEmbedHtml(videoId),
            baseUrl: 'https://www.youtube-nocookie.com',
          );
          print('🎥 HTML con iframe cargado para video ID: $videoId');
        } catch (e) {
          // Si falla la creación del WebViewController (puede pasar en Linux),
          // mostrar un mensaje y permitir abrir en navegador externo
          print('❌ Error creando WebViewController: $e');
          _webViewController = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'No se pudo cargar el video. Usa el botón para abrirlo en el navegador.',
                ),
                action: SnackBarAction(
                  label: 'Abrir',
                  onPressed: () async {
                    final uri = Uri.parse(widget.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            );
          }
        }
      }
    }

    return SafeArea(
      child: Column(
        children: [
          // WebView para reproducir el video embebido
          if (isYouTube && videoId != null && _webViewController != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: WebViewWidget(controller: _webViewController!),
                ),
              ),
            )
          else if (isYouTube && videoId != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Cargando reproductor de video...'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Video de Streaming',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(widget.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir externamente'),
                    ),
                  ],
                ),
              ),
            ),

          // Información del video (solo para YouTube)
          if (isYouTube && videoId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Video de Streaming',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Este video está alojado en una plataforma externa',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si no se reproduce, usa "Abrir externamente"',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://www.youtube.com/watch?v=$videoId',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Ver en YouTube'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(widget.url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir externamente'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            widget.fileName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Reproductor de audio pendiente de implementar',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Reproducir en reproductor externo'),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackView(FileType fileType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getIcon(fileType), size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            widget.fileName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Visualización no disponible para este tipo de archivo',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Abrir en navegador'),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(FileType fileType) {
    switch (fileType) {
      case FileType.image:
        return Icons.image;
      case FileType.document:
        return Icons.description;
      case FileType.text:
        return Icons.text_snippet;
      case FileType.multimedia:
        return Icons.videocam;
      case FileType.other:
        return Icons.insert_drive_file;
    }
  }

  /// Descargar archivo usando file_picker para elegir ubicación
  Future<void> _downloadFile(BuildContext context) async {
    final fileType = _getFileType(widget.url);

    // No permitir descargar URLs de streaming
    if (fileType == FileType.multimedia && _isStreamingVideo(widget.url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede descargar videos de streaming'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Mostrar diálogo de selección de ubicación
      String? outputPath = await file_picker.FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo',
        fileName: widget.fileName.isNotEmpty
            ? widget.fileName
            : _getDefaultFileName(),
        type: file_picker.FileType.any,
      );

      if (outputPath == null) {
        // Usuario canceló
        return;
      }

      // Mostrar indicador de progreso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Descargando archivo...'),
              ],
            ),
            duration: Duration(
              hours: 1,
            ), // Duración larga para mostrar progreso
          ),
        );
      }

      // Descargar el archivo
      final response = await http.get(Uri.parse(widget.url));

      if (response.statusCode != 200) {
        throw Exception('Error al descargar: ${response.statusCode}');
      }

      // Guardar el archivo
      final file = File(outputPath);
      await file.writeAsBytes(response.bodyBytes);

      // Cerrar snackbar de progreso
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Archivo descargado: ${path.basename(outputPath)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al descargar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Obtener nombre de archivo por defecto basado en la URL y tipo
  String _getDefaultFileName() {
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
        return lastSegment;
      }
    }

    // Si no hay extensión, agregar una basada en el tipo de archivo
    final fileType = _getFileType(widget.url);
    final extension = switch (fileType) {
      FileType.image => '.png',
      FileType.document => '.pdf',
      FileType.text => '.txt',
      FileType.multimedia => '.mp4',
      FileType.other => '',
    };

    return 'archivo_descargado$extension';
  }
}
