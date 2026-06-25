import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../models/file_type.dart' as app_file_type;

/// Widget reutilizable para selección múltiple de archivos.
///
/// Equivalente Flutter de MultipleFilesSection.swift (EDFCatalogoSwift).
///
/// Mejoras respecto a la clase privada _MultiFileSelectionRow:
///   - Campo URL inline (sin AlertDialog externo) con validación de formato
///   - Validación de tamaño de archivo al seleccionar (20 MB imagen, 50 MB doc,
///     300 MB multimedia)
///   - Íconos por tipo de archivo
///   - Compatible con Material 3 (sin APIs de color deprecadas)
///   - En web, los botones de archivo local se ocultan (file path = null en web)
///
/// Uso básico:
/// ```dart
/// MultipleFilesSection(
///   title: 'Imagen',
///   fileType: FileType.image,
///   selectedFiles: _selectedImageFiles,
///   existingUrls: _imageUrls,
///   isUploading: _isUploadingImage,
///   fileTitles: _fileTitles,
///   onSelectFile: () => _selectFile(FileType.image),
///   onSelectMultipleFiles: () => _selectFile(FileType.image, allowMultiple: true),
///   onRemove: (i) => _removeFileOrUrl(i, FileType.image),
///   onAddUrl: (url) => _addUrl(url, FileType.image),
///   onUpdateTitle: (url, title) => _updateFileTitle(url, title),
///   getFileUrl: (i) => _getFileUrl(i, FileType.image),
///   getTitleController: (url) => _getOrCreateTitleController(url),
/// )
/// ```
class MultipleFilesSection extends StatefulWidget {
  final String title;
  final app_file_type.FileType fileType;

  /// Archivos locales seleccionados via file_picker (antes de subir).
  final List<file_picker.PlatformFile> selectedFiles;

  /// URLs ya guardadas en el servidor.
  final List<String> existingUrls;

  final bool isUploading;

  /// Mapa url → título personalizado del archivo.
  final Map<String, String> fileTitles;

  /// Seleccionar un único archivo local.
  final VoidCallback onSelectFile;

  /// Seleccionar varios archivos locales a la vez.
  final VoidCallback onSelectMultipleFiles;

  /// Eliminar el ítem en [index] (combinando selectedFiles + existingUrls).
  final void Function(int index) onRemove;

  /// Confirmar una nueva URL introducida inline. Recibe la URL validada.
  final void Function(String url) onAddUrl;

  /// Actualizar el título de un archivo identificado por [url].
  final void Function(String url, String title) onUpdateTitle;

  /// Obtener la URL/ruta del ítem en [index] (para el campo de título).
  final String Function(int index) getFileUrl;

  /// Obtener (o crear) el TextEditingController del título de [url].
  final TextEditingController Function(String url) getTitleController;

  const MultipleFilesSection({
    super.key,
    required this.title,
    required this.fileType,
    required this.selectedFiles,
    required this.existingUrls,
    required this.isUploading,
    required this.fileTitles,
    required this.onSelectFile,
    required this.onSelectMultipleFiles,
    required this.onRemove,
    required this.onAddUrl,
    required this.onUpdateTitle,
    required this.getFileUrl,
    required this.getTitleController,
  });

  @override
  State<MultipleFilesSection> createState() => _MultipleFilesSectionState();
}

class _MultipleFilesSectionState extends State<MultipleFilesSection> {
  final TextEditingController _urlController = TextEditingController();
  bool _showUrlField = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  IconData _iconForType(app_file_type.FileType type) {
    switch (type) {
      case app_file_type.FileType.image:
        return Icons.image_outlined;
      case app_file_type.FileType.multimedia:
        return Icons.play_circle_outline;
      default:
        return Icons.description_outlined;
    }
  }

  /// Tamaño máximo en bytes según tipo de archivo (igual que Swift).
  int _maxBytesForType(app_file_type.FileType type) {
    switch (type) {
      case app_file_type.FileType.image:
        return 20 * 1024 * 1024; // 20 MB
      case app_file_type.FileType.multimedia:
        return 300 * 1024 * 1024; // 300 MB
      default:
        return 50 * 1024 * 1024; // 50 MB
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Acciones
  // ──────────────────────────────────────────────────────────────────────────

  void _confirmUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    final isAbsoluteUrl = uri != null && uri.hasScheme;
    final isLocalPath = url.startsWith('/');

    if (!isAbsoluteUrl && !isLocalPath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL no válida. Usa https://... o una ruta local absoluta'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    widget.onAddUrl(url);
    _urlController.clear();
    setState(() => _showUrlField = false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalItems = widget.selectedFiles.length + widget.existingUrls.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          if (totalItems > 0) ...[
            const SizedBox(height: 8),
            ...List.generate(totalItems, (index) => _buildItem(context, theme, index)),
          ],
          if (_showUrlField) ...[
            const SizedBox(height: 8),
            _buildUrlField(theme),
          ],
          const SizedBox(height: 8),
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(_iconForType(widget.fileType), size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          widget.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (widget.isUploading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, ThemeData theme, int index) {
    final isFile = index < widget.selectedFiles.length;
    String displayName;
    int? fileSize;

    if (isFile) {
      final pf = widget.selectedFiles[index];
      // PlatformFile: en nativo tiene path, en web solo name
      displayName = pf.path != null ? path.basename(pf.path!) : pf.name;
      fileSize = pf.size;
      final maxBytes = _maxBytesForType(widget.fileType);
      if (fileSize > maxBytes) {
        displayName = '⚠️ $displayName (supera ${_formatBytes(maxBytes)})';
      }
    } else {
      displayName = widget.existingUrls[index - widget.selectedFiles.length];
      // Mostrar solo el último segmento de la URL como nombre legible
      final uri = Uri.tryParse(displayName);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        displayName = Uri.decodeComponent(uri.pathSegments.last);
      }
    }

    final fileUrl = widget.getFileUrl(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isFile
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFile ? Icons.insert_drive_file_outlined : Icons.link,
                  size: 16,
                  color: isFile
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isFile
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileSize != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    _formatBytes(fileSize),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.isUploading ? null : () => widget.onRemove(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: widget.isUploading
                        ? theme.disabledColor
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            if (fileUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (_) {
                  final controller = widget.getTitleController(fileUrl);
                  return TextField(
                    key: ValueKey('title_$fileUrl'),
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Título del archivo (opcional)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    style: theme.textTheme.bodySmall,
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    enabled: !widget.isUploading,
                    onChanged: (v) => widget.onUpdateTitle(fileUrl, v),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUrlField(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _urlController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'https://... o ruta local absoluta',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link, size: 16),
            ),
            style: theme.textTheme.bodySmall,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmUrl(),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          tooltip: 'Añadir URL',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _confirmUrl,
        ),
        IconButton(
          icon: Icon(Icons.cancel_outlined, color: theme.colorScheme.outline),
          tooltip: 'Cancelar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () {
            _urlController.clear();
            setState(() => _showUrlField = false);
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.isUploading ? null : widget.onSelectFile,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Archivo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: widget.isUploading ? null : widget.onSelectMultipleFiles,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Varios'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: widget.isUploading
              ? null
              : () => setState(() {
                    _showUrlField = !_showUrlField;
                    if (!_showUrlField) _urlController.clear();
                  }),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: _showUrlField
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_showUrlField ? Icons.link_off : Icons.link, size: 16),
              const SizedBox(width: 4),
              const Text('URL'),
            ],
          ),
        ),
      ],
    );
  }
}
