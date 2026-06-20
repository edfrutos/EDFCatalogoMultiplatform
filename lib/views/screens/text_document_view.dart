import 'dart:convert' show utf8, latin1;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Visor de documentos de texto completo con estadísticas, copia y compartir.
///
/// Equivalente Flutter de TextDocumentView.swift (EDFCatalogoSwift).
///
/// Formatos soportados:
///   - Texto plano (.txt, .log, .csv, .tsv)
///   - Markdown (.md, .markdown) — renderizado con flutter_markdown_plus
///   - JSON / XML — monoespaciado con resaltado básico
///   - HTML (.html, .htm) — extrae texto plano (sin renderizado completo)
///   - RTF (.rtf) — extrae texto plano eliminando códigos RTF
///
/// Uso:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => TextDocumentView(url: fileUrl, fileName: 'notas.md'),
/// ));
/// ```
class TextDocumentView extends StatefulWidget {
  final String url;
  final String fileName;

  const TextDocumentView({super.key, required this.url, required this.fileName});

  @override
  State<TextDocumentView> createState() => _TextDocumentViewState();
}

class _TextDocumentViewState extends State<TextDocumentView> {
  String? _content;
  bool _isLoading = true;
  String? _errorMessage;

  // Estadísticas (como TextDocumentView.swift)
  int _wordCount = 0;
  int _lineCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tipo de archivo
  // ──────────────────────────────────────────────────────────────────────────

  bool get _isMarkdown {
    final lower = widget.url.toLowerCase();
    final nameLower = widget.fileName.toLowerCase();
    return lower.contains('.md') ||
        lower.contains('.markdown') ||
        nameLower.endsWith('.md') ||
        nameLower.endsWith('.markdown');
  }

  bool get _isMonospaced {
    final lower = widget.fileName.toLowerCase();
    return lower.endsWith('.json') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.tsv') ||
        lower.endsWith('.log') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.toml');
  }

  String get _fileTypeLabel {
    final ext = widget.fileName.split('.').last.toLowerCase();
    const labels = {
      'txt': 'Texto plano',
      'md': 'Markdown',
      'markdown': 'Markdown',
      'json': 'JSON',
      'xml': 'XML',
      'html': 'HTML',
      'htm': 'HTML',
      'csv': 'CSV',
      'tsv': 'TSV',
      'log': 'Log',
      'rtf': 'Rich Text',
      'yaml': 'YAML',
      'yml': 'YAML',
      'toml': 'TOML',
    };
    return labels[ext] ?? 'Documento de texto';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Carga
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(widget.url);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      String text;
      try {
        text = utf8.decode(response.bodyBytes, allowMalformed: false);
      } catch (_) {
        try {
          text = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (_) {
          text = latin1.decode(response.bodyBytes);
        }
      }

      // Post-proceso según formato
      final ext = widget.fileName.split('.').last.toLowerCase();
      if (ext == 'rtf') {
        text = _stripRtf(text);
      } else if (ext == 'html' || ext == 'htm') {
        text = _stripHtml(text);
      }

      _calculateStats(text);

      setState(() {
        _content = text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Post-proceso de formatos
  // ──────────────────────────────────────────────────────────────────────────

  /// Elimina la mayoría de códigos RTF para mostrar texto legible.
  String _stripRtf(String rtf) {
    var text = rtf
        .replaceAll(RegExp(r'\\[a-z]+\d*\s?'), ' ')
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty || text.length < 10 ? rtf : text;
  }

  /// Extrae el texto plano de un documento HTML básico.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Estadísticas
  // ──────────────────────────────────────────────────────────────────────────

  void _calculateStats(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lines = text.split('\n').length;
    _wordCount = words;
    _lineCount = lines;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Acciones
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _copyToClipboard() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contenido copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _content ?? widget.url,
          subject: widget.fileName,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              _fileTypeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_content != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copiar todo',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir',
              onPressed: _share,
            ),
          ],
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
          Expanded(child: _buildBody(theme)),
          if (!_isLoading && _errorMessage == null && _content != null)
            _buildStatsBar(theme),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando documento…'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildError(theme);
    }

    if (_content == null) {
      return const Center(child: Text('Sin contenido'));
    }

    if (_isMarkdown) {
      return _buildMarkdownView(theme);
    }

    return _buildPlainTextView(theme);
  }

  Widget _buildMarkdownView(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Markdown(
      data: _content!,
      selectable: false, // evita crash conocido de flutter_markdown
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        h2: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        h4: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          color: isDark ? Colors.lightGreenAccent : Colors.purple[900],
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null) launchUrl(uri);
        }
      },
    );
  }

  Widget _buildPlainTextView(ThemeData theme) {
    final isCode = _isMonospaced;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: isCode
            ? TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface,
              )
            : theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar el documento',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadDocument,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(widget.url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Abrir en navegador'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de estadísticas inferior (equivalente al Controls Bar de Swift).
  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$_wordCount palabras  •  $_lineCount líneas',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            _fileTypeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
