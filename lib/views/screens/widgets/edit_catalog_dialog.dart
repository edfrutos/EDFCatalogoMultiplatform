import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import '../../../models/catalog.dart';
import '../../../models/file_type.dart';
import '../../../utils/app_theme.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../services/s3_service.dart';

class EditCatalogDialog extends StatefulWidget {
  final Catalog catalog;
  final Function(
    String name,
    String description,
    List<String> columns,
    String? thumbnailUrl,
  ) onSave;

  const EditCatalogDialog({
    super.key,
    required this.catalog,
    required this.onSave,
  });

  @override
  State<EditCatalogDialog> createState() => _EditCatalogDialogState();
}

class _EditCatalogDialogState extends State<EditCatalogDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _colsCtrl;

  file_picker.PlatformFile? _selectedPlatformFile;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  bool _shouldRemoveImage = false;

  String? _presignedThumbnailUrl;
  String? _presignedFirstRowImageUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.catalog.name);
    _descCtrl = TextEditingController(text: widget.catalog.description);
    _colsCtrl = TextEditingController(
        text: widget.catalog.columns.join(', '));
    _loadPresignedUrls();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _colsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresignedUrls() async {
    final s3 = S3Service();
    if (widget.catalog.thumbnailUrl != null) {
      try {
        final uri = await s3.getPresignedUrl(key: widget.catalog.thumbnailUrl!);
        if (mounted) setState(() => _presignedThumbnailUrl = uri.toString());
      } catch (_) {}
    }
    final firstRowImage = widget.catalog.getFirstImageFromRows();
    if (firstRowImage != null) {
      try {
        final uri = await s3.getPresignedUrl(key: firstRowImage);
        if (mounted) setState(() => _presignedFirstRowImageUrl = uri.toString());
      } catch (_) {}
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final columns = _colsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String? thumbnailUrl = widget.catalog.thumbnailUrl;

    if (_shouldRemoveImage && _selectedPlatformFile == null) {
      thumbnailUrl = null;
    } else if (_selectedPlatformFile != null) {
      setState(() => _isUploadingImage = true);
      try {
        final userId = context.read<AuthViewModel>().currentUser?.id ??
            widget.catalog.userId;
        final pf = _selectedPlatformFile!;
        if (kIsWeb) {
          thumbnailUrl = await S3Service().uploadBytes(
            bytes: pf.bytes!,
            fileName: pf.name,
            userId: userId,
            catalogId: widget.catalog.id,
            fileType: FileType.image,
          );
        } else {
          thumbnailUrl = await S3Service().uploadFile(
            filePath: pf.path!,
            userId: userId,
            catalogId: widget.catalog.id,
            fileType: FileType.image,
          );
        }
      } catch (e) {
        setState(() { _isUploadingImage = false; _isSaving = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al subir imagen: $e'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      setState(() => _isUploadingImage = false);
    }

    widget.onSave(_nameCtrl.text.trim(), _descCtrl.text.trim(), columns,
        thumbnailUrl);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _selectImage() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final pf = result.files.single;
        if (kIsWeb ? pf.bytes != null : pf.path != null) {
          setState(() {
            _selectedPlatformFile = pf;
            _shouldRemoveImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _removeImage() => setState(() {
        _selectedPlatformFile = null;
        _shouldRemoveImage = true;
      });

  Widget _buildThumbnail(ColorScheme cs) {
    Widget imgContent;

    if (_selectedPlatformFile != null) {
      if (kIsWeb && _selectedPlatformFile!.bytes != null) {
        imgContent = Image.memory(_selectedPlatformFile!.bytes!,
            fit: BoxFit.cover);
      } else if (!kIsWeb && _selectedPlatformFile!.path != null) {
        imgContent = Image.file(
            File(_selectedPlatformFile!.path!) as dynamic,
            fit: BoxFit.cover);
      } else {
        imgContent = Icon(Icons.image_outlined,
            size: 40, color: cs.onSurface.withValues(alpha: 0.3));
      }
    } else if (_presignedThumbnailUrl != null && !_shouldRemoveImage) {
      imgContent = CachedNetworkImage(
        imageUrl: _presignedThumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
        errorWidget: (_, _, _) => Icon(Icons.broken_image_rounded,
            size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
      );
    } else if (_presignedFirstRowImageUrl != null) {
      imgContent = CachedNetworkImage(
        imageUrl: _presignedFirstRowImageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
        errorWidget: (_, _, _) => Icon(Icons.broken_image_rounded,
            size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
      );
    } else {
      imgContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined,
              size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 6),
          Text('Sin imagen',
              style: GoogleFonts.inter(
                  fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
        ],
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: imgContent,
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _isUploadingImage ? null : _selectImage,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded,
                  size: 15, color: cs.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasThumbnail =
        _selectedPlatformFile != null ||
        (widget.catalog.thumbnailUrl != null && !_shouldRemoveImage);

    return AlertDialog(
      icon: Icon(Icons.edit_rounded, color: cs.primary, size: 28),
      title: Text('Editar catálogo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),

                // ── Miniatura ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(cs),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Imagen del catálogo',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.6))),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _isUploadingImage ? null : _selectImage,
                            icon: const Icon(Icons.photo_library_rounded,
                                size: 14),
                            label: const Text('Seleccionar'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                          ),
                          if (hasThumbnail) ...[
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: _removeImage,
                              icon: Icon(Icons.delete_rounded,
                                  size: 14, color: cs.error),
                              label: Text('Quitar',
                                  style:
                                      TextStyle(color: cs.error)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                side: BorderSide(color: cs.error),
                              ),
                            ),
                          ],
                          if (_isUploadingImage) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary)),
                                const SizedBox(width: 6),
                                Text('Subiendo...',
                                    style: GoogleFonts.inter(
                                        fontSize: 11)),
                              ],
                            ),
                          ],
                          if (widget.catalog.thumbnailUrl == null &&
                              widget.catalog.getFirstImageFromRows() !=
                                  null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Usando primera imagen de las filas',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Campos ────────────────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.label_rounded, size: 18),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description_rounded, size: 18),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _colsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Columnas separadas por comas',
                    prefixIcon: Icon(Icons.view_column_rounded, size: 18),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSave(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_isSaving || _isUploadingImage)
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_isSaving || _isUploadingImage) ? null : _handleSave,
          icon: (_isSaving || _isUploadingImage)
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.onPrimary))
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(
              (_isSaving || _isUploadingImage) ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}
