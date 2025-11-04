import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../models/catalog.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../services/s3_service.dart';
import '../../../models/file_type.dart';

class EditCatalogDialog extends StatefulWidget {
  final Catalog catalog;
  final Function(
    String name,
    String description,
    List<String> columns,
    String? thumbnailUrl,
  )
  onSave;

  const EditCatalogDialog({
    super.key,
    required this.catalog,
    required this.onSave,
  });

  @override
  State<EditCatalogDialog> createState() => _EditCatalogDialogState();
}

class _EditCatalogDialogState extends State<EditCatalogDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _columnsController;
  final _formKey = GlobalKey<FormState>();

  // Foto de perfil del catálogo
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  bool _shouldRemoveImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.catalog.name);
    _descriptionController = TextEditingController(
      text: widget.catalog.description,
    );
    _columnsController = TextEditingController(
      text: widget.catalog.columns.join(', '),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _columnsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final columns = _columnsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String? thumbnailUrl = widget.catalog.thumbnailUrl;

    // Si se debe eliminar la imagen, establecer como null
    if (_shouldRemoveImage && _selectedImageFile == null) {
      thumbnailUrl = null;
    }
    // Subir imagen si hay una nueva seleccionada
    else if (_selectedImageFile != null) {
      setState(() {
        _isUploadingImage = true;
      });

      try {
        final authViewModel = context.read<AuthViewModel>();
        final userId = authViewModel.currentUser?.id ?? widget.catalog.userId;

        final s3Service = S3Service();
        thumbnailUrl = await s3Service.uploadFile(
          filePath: _selectedImageFile!.path,
          userId: userId,
          catalogId: widget.catalog.id,
          fileType: FileType.image,
        );

        print('✅ Imagen del catálogo subida: $thumbnailUrl');
      } catch (e) {
        setState(() {
          _isUploadingImage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir imagen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingImage = false;
      });
    }

    widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim(),
      columns,
      thumbnailUrl,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Seleccionar imagen usando file_picker
  Future<void> _selectImage() async {
    try {
      file_picker.FilePickerResult? result = await file_picker
          .FilePicker
          .platform
          .pickFiles(
            type: file_picker.FileType.image,
            allowMultiple: false,
            withData: false,
            withReadStream: false,
          );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        setState(() {
          _selectedImageFile = File(filePath);
          _shouldRemoveImage = false;
        });
        print('✅ Imagen seleccionada: $filePath');
      }
    } catch (e) {
      print('❌ Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Eliminar imagen
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _shouldRemoveImage = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar catálogo'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imagen del catálogo
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          // Imagen o placeholder
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _selectedImageFile != null
                                  ? Image.file(
                                      _selectedImageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : widget.catalog.thumbnailUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.catalog.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                          ),
                                    )
                                  : widget.catalog.getFirstImageFromRows() !=
                                        null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.catalog
                                          .getFirstImageFromRows()!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                          ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          // Botón de editar
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: _isUploadingImage
                                    ? null
                                    : _selectImage,
                                tooltip: 'Cambiar imagen',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _selectImage,
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('Seleccionar'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                          if ((_selectedImageFile != null ||
                                  widget.catalog.thumbnailUrl != null) &&
                              !_isUploadingImage) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _removeImage,
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Eliminar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isUploadingImage)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Subiendo imagen...',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      if (widget.catalog.thumbnailUrl == null &&
                          widget.catalog.getFirstImageFromRows() != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Mostrando primera imagen de las filas',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _columnsController,
                  decoration: const InputDecoration(
                    labelText: 'Columnas separadas por comas',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSave(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isUploadingImage ? null : _handleSave,
          child: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
