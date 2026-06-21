import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart' as fv;
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:convert' show utf8, latin1;
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
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

  // MediaKit para Linux
  Player? _mediaKitPlayer;
  VideoController? _mediaKitController;
  bool _isLinuxMediaLoading = false;
  String? _linuxMediaError;
  String? _lastLinuxOriginalUrl;

  // Para archivos de texto
  String? _textContent;
  bool _isLoadingText = false;
  String? _textError;

  // Para WebView de YouTube
  fv.WebViewController? _webViewController;
  bool _hasLoadedInitialContent = false;
  String? _currentVideoId;
  bool _webViewFailed = false; // Flag para indicar si WebView falló

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

    if (fileType == FileType.multimedia) {
      if (!kIsWeb && Platform.isLinux) {
        _initializeLinuxMediaKit();
      } else if (!_isStreamingVideo(widget.url)) {
        _initializeVideo();
      }
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

  @override
  void didUpdateWidget(covariant FileViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url == oldWidget.url) return;

    final fileType = _getFileType(widget.url);
    if (!kIsWeb && Platform.isLinux && fileType == FileType.multimedia) {
      _initializeLinuxMediaKit(force: true);
    } else if (fileType == FileType.multimedia &&
        !_isStreamingVideo(widget.url)) {
      _initializeVideo();
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

  Future<String?> _extractYouTubeStreamUrl(String youtubeUrl) async {
    // Primer intento: youtube_explode_dart (no requiere dependencias externas)
    try {
      final ytClient = yt.YoutubeExplode();
      try {
        final videoId = yt.VideoId(youtubeUrl);
        final manifest =
            await ytClient.videos.streamsClient.getManifest(videoId);
        final muxed = manifest.muxed;

        yt.MuxedStreamInfo? bestCandidate;
        for (final stream in muxed) {
          final height = stream.videoResolution.height;
          if (height <= 0) continue;
          if (height <= 720) {
            if (bestCandidate == null ||
                height > bestCandidate.videoResolution.height) {
              bestCandidate = stream;
            }
          }
        }
        bestCandidate ??=
            muxed.isNotEmpty ? muxed.first : null; // fallback a la mejor disponible

        if (bestCandidate != null) {
          final streamUrl = bestCandidate.url.toString();
          final preview = streamUrl.length > 100
              ? '${streamUrl.substring(0, 100)}...'
              : streamUrl;
          print(
            '✅ URL del stream extraída con youtube_explode_dart: $preview',
          );
          return streamUrl;
        } else {
          print('⚠️ youtube_explode_dart no encontró streams muxed.');
        }
      } finally {
        ytClient.close();
      }
    } catch (e) {
      print('⚠️ youtube_explode_dart falló: $e');
    }

    // Segundo intento: yt-dlp (requiere ejecutable disponible en el sistema)
    try {
      print('🔍 youtube_explode no funcionó; probando con yt-dlp...');
      final result = await Process.run(
        'yt-dlp',
        ['-g', '-f', 'best[height<=720]', youtubeUrl],
        runInShell: false,
      );

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final streamUrl = result.stdout.toString().trim();
        final urlPreview =
            streamUrl.length > 100 ? '${streamUrl.substring(0, 100)}...' : streamUrl;
        print('✅ URL del stream extraída con yt-dlp: $urlPreview');
        return streamUrl;
      } else {
        print('⚠️ yt-dlp no pudo extraer la URL: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Error ejecutando yt-dlp: $e');
    }

    return null;
  }

  Future<void> _initializeLinuxMediaKit({bool force = false}) async {
    if (kIsWeb || !Platform.isLinux) return;

    final originalUrl = widget.url;

    if (!force &&
        _mediaKitPlayer != null &&
        _lastLinuxOriginalUrl == originalUrl &&
        _linuxMediaError == null) {
      // Ya estamos reproduciendo este recurso.
      return;
    }

    setState(() {
      _isLinuxMediaLoading = true;
      _linuxMediaError = null;
    });

    try {
      String mediaUrl = originalUrl;
      if (_isStreamingVideo(originalUrl)) {
        final streamUrl = await _extractYouTubeStreamUrl(originalUrl);
        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception(
            'No se pudo obtener un stream reproducible desde YouTube. '
            'Verifica tu conexión o abre el video en el navegador. '
            'Instalar la herramienta “yt-dlp” puede ayudar como método alternativo.',
          );
        }
        mediaUrl = streamUrl;
      }

      if (_mediaKitPlayer == null || force) {
        await _mediaKitPlayer?.dispose();
        _mediaKitPlayer = Player();
        _mediaKitController = VideoController(
          _mediaKitPlayer!,
          configuration: const VideoControllerConfiguration(
            vo: 'libmpv',
            hwdec: 'auto',
            width: 1280,
            height: 720,
          ),
        );
      }

      _lastLinuxOriginalUrl = originalUrl;

      await _mediaKitPlayer!.open(Media(mediaUrl));
      await _mediaKitPlayer!.play();

      if (!mounted) return;
      setState(() {
        _isLinuxMediaLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error inicializando MediaKit en Linux: $e');
      await _mediaKitPlayer?.stop();
      if (!mounted) return;
      setState(() {
        _linuxMediaError = e.toString();
        _isLinuxMediaLoading = false;
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
    _mediaKitPlayer?.dispose();
    _mediaKitPlayer = null;
    _mediaKitController = null;
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
    print('🔍 _buildContent: fileType=$fileType, url=${widget.url}, fileName=${widget.fileName}');
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
        print('🎬 FileType.multimedia detectado');
        print('   - _isStreamingVideo: ${_isStreamingVideo(widget.url)}');
        print('   - _isVideo: ${_isVideo(widget.url)}');
        print('   - _isAudio: ${_isAudio(widget.url)}');
        
        // En Linux, usar MediaKit para TODOS los videos (streaming y MP4)
        final isLinux = !kIsWeb && Platform.isLinux;
        print('🐧 Es Linux: $isLinux');
        
        if (isLinux && (_isStreamingVideo(widget.url) || _isVideo(widget.url))) {
          print('🎬 Usando MediaKit para video en Linux: ${widget.url}');
          return _buildLinuxMediaKitView();
        }
        
        // Para otras plataformas o si no es video
        if (_isStreamingVideo(widget.url)) {
          print('🎥 Detectado como video de streaming: ${widget.url}');
          return _buildStreamingVideoView();
        } else if (_isVideo(widget.url)) {
          print('🎬 Detectado como video MP4: ${widget.url}');
          print('📺 Usando video_player (no Linux)');
          return _buildVideoView();
        } else if (_isAudio(widget.url)) {
          print('🔊 Detectado como audio: ${widget.url}');
          return _buildAudioView();
        } else {
          print('⚠️ Multimedia no reconocido, usando fallback');
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
    return _EmbeddedPdfViewer(url: widget.url, fileName: widget.fileName);
  }

  Widget _buildLinuxVideoFallback(String message) {
    return SafeArea(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 72, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'No se puede mostrar el video aquí',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildLinuxVideoActions(includeRetry: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinuxVideoActions({bool includeRetry = false}) {
    final List<Widget> buttons = [];

    if (includeRetry) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isLinuxMediaLoading
              ? null
              : () async {
                  await _initializeLinuxMediaKit(force: true);
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    buttons.addAll([
      ElevatedButton.icon(
        onPressed: () async {
          try {
            final uri = Uri.parse(widget.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo abrir el enlace'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al abrir el enlace: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.open_in_browser),
        label: const Text('Abrir en navegador'),
      ),
      ElevatedButton.icon(
        onPressed: () async {
          try {
            final result = await Process.run(
              'xdg-open',
              [widget.url],
              runInShell: false,
            );
            if (result.exitCode != 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Error al abrir el video: ${result.stderr}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al abrir el video: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir en reproductor externo'),
      ),
    ]);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: buttons,
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

    // Detectar si estamos en Linux
    final isLinux = !kIsWeb && Platform.isLinux;
    
    // En Linux, si WebView falló o no está disponible, usar fallback directamente
    // Esto evita intentar crear el WebViewController que falla en Linux
    if (isLinux && isYouTube && (_webViewFailed || _webViewController == null)) {
      // Si no hemos intentado crear el WebViewController aún, marcarlo como fallido
      // para evitar intentos futuros
      if (!_webViewFailed && _webViewController == null) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _webViewFailed = true;
            });
          }
        });
      }
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
                  'El reproductor integrado no está disponible. El video se abrirá en tu navegador predeterminado.',
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
    // NO intentar en Linux si ya falló antes
    if (isYouTube && videoId != null && !_webViewFailed && !isLinux) {
      if (_webViewController == null || _currentVideoId != videoId) {
        print(
          '🔄 Inicializando/reinicializando WebView para video: $videoId (anterior: $_currentVideoId)',
        );

        // Resetear el flag de carga inicial si cambió el video
        if (_currentVideoId != videoId) {
          _hasLoadedInitialContent = false;
          _currentVideoId = videoId;
        }

        // Inicializar WebViewController de forma asíncrona para evitar errores durante el build
        Future.microtask(() async {
          if (!mounted || _webViewFailed) return;
          
          try {
            final controller = fv.WebViewController()
              ..setJavaScriptMode(fv.JavaScriptMode.unrestricted)
              ..setNavigationDelegate(
                fv.NavigationDelegate(
                  onNavigationRequest: (fv.NavigationRequest request) {
                    // Si es el main frame
                    if (request.isMainFrame) {
                      // Permitir solo la carga inicial del HTML local
                      if (!_hasLoadedInitialContent) {
                        // Permitir la primera navegación (puede ser cualquier cosa de la carga inicial)
                        _hasLoadedInitialContent = true;
                        print(
                          '✅ Permitida navegación inicial del main frame: ${request.url}',
                        );
                        return fv.NavigationDecision.navigate;
                      }

                      // Después de la carga inicial, bloquear TODAS las navegaciones del main frame
                      // IMPORTANTE: Esto previene que YouTube intente redirigir o abrir ventanas nuevas
                      print(
                        '🚫 BLOQUEADA navegación principal (ya cargado): ${request.url}',
                      );
                      return fv.NavigationDecision.prevent;
                    }

                    // Permitir TODAS las navegaciones dentro del iframe (subframes)
                    // Esto incluye recursos de YouTube dentro del embed que necesita cargar
                    print('✅ Permitida navegación de subframe: ${request.url}');
                    return fv.NavigationDecision.navigate;
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
                  onWebResourceError: (fv.WebResourceError error) {
                    print('❌ Error en WebView: ${error.description}');
                    print('   Error code: ${error.errorCode}');
                    print('   Error type: ${error.errorType}');
                    print('   URL: ${error.url}');
                    // Si es un error crítico, marcar como fallido
                    if (error.errorCode != 0 && error.errorType != fv.WebResourceErrorType.unknown) {
                      if (mounted) {
                        setState(() {
                          _webViewFailed = true;
                          _webViewController = null;
                        });
                      }
                    }
                  },
                ),
              );

            // Cargar HTML con iframe embebido
            // IMPORTANTE: Usar el dominio de YouTube como baseUrl para que el iframe funcione
            await controller.loadHtmlString(
              _getYouTubeEmbedHtml(videoId),
              baseUrl: 'https://www.youtube-nocookie.com',
            );
            
            if (mounted && !_webViewFailed) {
              setState(() {
                _webViewController = controller;
              });
              print('🎥 HTML con iframe cargado para video ID: $videoId');
            }
          } catch (e, stackTrace) {
            // Si falla la creación del WebViewController (puede pasar en Linux sin WebKitGTK),
            // marcar como fallido y mostrar opción de abrir en navegador externo
            print('❌ Error creando WebViewController: $e');
            print('   Stack trace: $stackTrace');
            if (mounted) {
              setState(() {
                _webViewController = null;
                _webViewFailed = true;
              });
            }
          }
        });
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
                  child: fv.WebViewWidget(controller: _webViewController!),
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
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

  double _currentLinuxAspectRatio() {
    final width = _mediaKitPlayer?.state.width;
    final height = _mediaKitPlayer?.state.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 16 / 9;
  }

  Widget _buildLinuxMediaKitView() {
    if (_linuxMediaError != null) {
      return _buildLinuxVideoFallback(_linuxMediaError!);
    }

    if (_mediaKitPlayer == null || _mediaKitController == null) {
      if (!_isLinuxMediaLoading) {
        _initializeLinuxMediaKit();
      }
      return SafeArea(
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Preparando reproductor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black87,
            child: _buildLinuxVideoActions(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aspect = _currentLinuxAspectRatio();
                double width = constraints.maxWidth;
                double height = width / aspect;
                if (height > constraints.maxHeight) {
                  height = constraints.maxHeight;
                  width = height * aspect;
                }

                return Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.black,
                          child: Video(
                            controller: _mediaKitController!,
                            controls: AdaptiveVideoControls,
                          ),
                        ),
                        if (_isLinuxMediaLoading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const _LinuxVideoLoadingOverlay(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinuxVideoLoadingOverlay extends StatelessWidget {
  const _LinuxVideoLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Preparando el vídeo…',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Si tarda demasiado, prueba abrirlo en el navegador.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visor de PDF embebido con navegación y zoom
// Usa PdfViewerView como pantalla completa al abrir desde otros contextos;
// aquí proporciona los controles dentro del contenedor padre (FileViewerView).
// ─────────────────────────────────────────────────────────────────────────────

class _EmbeddedPdfViewer extends StatefulWidget {
  final String url;
  final String fileName;

  const _EmbeddedPdfViewer({required this.url, required this.fileName});

  @override
  State<_EmbeddedPdfViewer> createState() => _EmbeddedPdfViewerState();
}

class _EmbeddedPdfViewerState extends State<_EmbeddedPdfViewer> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error al cargar PDF',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    SfPdfViewer.network(
                      widget.url,
                      controller: _controller,
                      enableDoubleTapZooming: true,
                      enableTextSelection: true,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      onDocumentLoaded: (d) => setState(() {
                        _totalPages = d.document.pages.count;
                        _isLoading = false;
                      }),
                      onDocumentLoadFailed: (d) => setState(() {
                        _errorMessage = d.description;
                        _isLoading = false;
                      }),
                      onPageChanged: (d) =>
                          setState(() => _currentPage = d.newPageNumber),
                      onZoomLevelChanged: (d) =>
                          setState(() => _zoomLevel = d.newZoomLevel),
                    ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
        if (!_isLoading && _errorMessage == null)
          _buildControls(theme),
      ],
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Página anterior',
            onPressed: _currentPage > 1
                ? () => _controller.previousPage()
                : null,
          ),
          Text(
            _totalPages > 0
                ? '$_currentPage / $_totalPages'
                : '…',
            style: theme.textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'Siguiente',
            onPressed: _currentPage < _totalPages
                ? () => _controller.nextPage()
                : null,
          ),
          const VerticalDivider(width: 20, indent: 8, endIndent: 8),
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            tooltip: 'Reducir zoom',
            onPressed: _zoomLevel > _zoomMin
                ? () {
                    final z =
                        (_zoomLevel - _zoomStep).clamp(_zoomMin, _zoomMax);
                    setState(() => _zoomLevel = z);
                    _controller.zoomLevel = z;
                  }
                : null,
          ),
          SizedBox(
            width: 46,
            child: Text(
              '${(_zoomLevel * 100).round()}%',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'Aumentar zoom',
            onPressed: _zoomLevel < _zoomMax
                ? () {
                    final z =
                        (_zoomLevel + _zoomStep).clamp(_zoomMin, _zoomMax);
                    setState(() => _zoomLevel = z);
                    _controller.zoomLevel = z;
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Restablecer zoom',
            onPressed: _zoomLevel != 1.0
                ? () {
                    setState(() => _zoomLevel = 1.0);
                    _controller.zoomLevel = 1.0;
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
