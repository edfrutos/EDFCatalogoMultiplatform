import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:path/path.dart' as path;
import '../../../models/catalog.dart';
import '../../../models/file_type.dart' as app_file_type;
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../services/s3_service.dart';
import '../../../utils/validators.dart';

class AddEditRowDialog extends StatefulWidget {
  final Catalog catalog;
  final CatalogRow? row;
  final Function(Map<String, String> data, RowFiles files) onSave;
  final VoidCallback onCancel;

  const AddEditRowDialog({
    super.key,
    required this.catalog,
    this.row,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<AddEditRowDialog> createState() => _AddEditRowDialogState();
}

class _AddEditRowDialogState extends State<AddEditRowDialog> {
  late Map<String, TextEditingController> _controllers;
  late RowFiles _files;
  bool _isSaving = false;

  // Archivos seleccionados
  File? _selectedImageFile;
  File? _selectedDocumentFile;
  File? _selectedMultimediaFile;

  // URLs existentes
  String? _imageUrl;
  String? _documentUrl;
  String? _multimediaUrl;

  // Estados de subida
  bool _isUploadingImage = false;
  bool _isUploadingDocument = false;
  bool _isUploadingMultimedia = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores para todas las columnas
    _controllers = {};
    for (final column in widget.catalog.columns) {
      _controllers[column] = TextEditingController(
        text: widget.row?.data[column] ?? '',
      );
    }
    _files = widget.row?.files ?? RowFiles();
    _imageUrl = _files.image;
    _documentUrl = _files.document;
    _multimediaUrl = _files.multimedia;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    final data = <String, String>{};
    for (final entry in _controllers.entries) {
      data[entry.key] = entry.value.text.trim();
    }

    // Subir archivos si hay alguno seleccionado
    final authViewModel = context.read<AuthViewModel>();
    final userId = authViewModel.currentUser?.id ?? '';

    if (_selectedImageFile != null) {
      setState(() {
        _isUploadingImage = true;
      });
      try {
        _imageUrl = await S3Service.shared.uploadFile(
          filePath: _selectedImageFile!.path,
          userId: userId,
          catalogId: widget.catalog.id,
          fileType: app_file_type.FileType.image,
        );
      } catch (e) {
        _uploadError = 'Error subiendo imagen: $e';
      } finally {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }

    if (_selectedDocumentFile != null) {
      setState(() {
        _isUploadingDocument = true;
      });
      try {
        _documentUrl = await S3Service.shared.uploadFile(
          filePath: _selectedDocumentFile!.path,
          userId: userId,
          catalogId: widget.catalog.id,
          fileType: app_file_type.FileType.document,
        );
      } catch (e) {
        _uploadError = 'Error subiendo documento: $e';
      } finally {
        setState(() {
          _isUploadingDocument = false;
        });
      }
    }

    if (_selectedMultimediaFile != null) {
      setState(() {
        _isUploadingMultimedia = true;
      });
      try {
        _multimediaUrl = await S3Service.shared.uploadFile(
          filePath: _selectedMultimediaFile!.path,
          userId: userId,
          catalogId: widget.catalog.id,
          fileType: app_file_type.FileType.multimedia,
        );
      } catch (e) {
        _uploadError = 'Error subiendo multimedia: $e';
      } finally {
        setState(() {
          _isUploadingMultimedia = false;
        });
      }
    }

    // Crear RowFiles con las URLs finales
    final finalFiles = RowFiles(
      image: _imageUrl,
      images: _files.images,
      document: _documentUrl,
      documents: _files.documents,
      multimedia: _multimediaUrl,
      multimediaFiles: _files.multimediaFiles,
    );

    widget.onSave(data, finalFiles);
    setState(() {
      _isSaving = true;
    });
  }

  Future<void> _selectFile(app_file_type.FileType fileType) async {
    file_picker.FilePickerResult? result;

    switch (fileType) {
      case app_file_type.FileType.image:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.image,
        );
        break;
      case app_file_type.FileType.document:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        );
        break;
      case app_file_type.FileType.text:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.custom,
          allowedExtensions: [
            'txt',
            'md',
            'markdown',
            'json',
            'xml',
            'csv',
            'log',
            'rtf',
          ],
        );
        break;
      case app_file_type.FileType.multimedia:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.media,
        );
        break;
      case app_file_type.FileType.other:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.any,
        );
        break;
    }

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        switch (fileType) {
          case app_file_type.FileType.image:
            _selectedImageFile = file;
            _imageUrl =
                null; // Limpiar URL existente si se selecciona nuevo archivo
            break;
          case app_file_type.FileType.document:
            _selectedDocumentFile = file;
            _documentUrl = null;
            break;
          case app_file_type.FileType.multimedia:
            _selectedMultimediaFile = file;
            _multimediaUrl = null;
            break;
          default:
            break;
        }
        _uploadError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.row != null;

    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Text(
                  isEdit ? 'Editar fila' : 'Añadir fila',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
            const Divider(),
            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campos de datos
                    const Text(
                      'Datos:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.catalog.columns.map((column) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: _controllers[column],
                          decoration: InputDecoration(
                            labelText: column,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            // Validación básica - puede extenderse con reglas por columna
                            return Validators.validateRequired(
                              value,
                              fieldName: column,
                            );
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Archivos
                    const Text(
                      'Archivos:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_uploadError != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    // Imagen
                    _FileSelectionRow(
                      title: 'Imagen',
                      selectedFile: _selectedImageFile,
                      existingUrl: _imageUrl,
                      isUploading: _isUploadingImage,
                      onSelect: () => _selectFile(app_file_type.FileType.image),
                      onRemove: () {
                        setState(() {
                          _selectedImageFile = null;
                          _imageUrl = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Documento
                    _FileSelectionRow(
                      title: 'Documento',
                      selectedFile: _selectedDocumentFile,
                      existingUrl: _documentUrl,
                      isUploading: _isUploadingDocument,
                      onSelect: () =>
                          _selectFile(app_file_type.FileType.document),
                      onRemove: () {
                        setState(() {
                          _selectedDocumentFile = null;
                          _documentUrl = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Multimedia
                    _FileSelectionRow(
                      title: 'Multimedia',
                      selectedFile: _selectedMultimediaFile,
                      existingUrl: _multimediaUrl,
                      isUploading: _isUploadingMultimedia,
                      onSelect: () =>
                          _selectFile(app_file_type.FileType.multimedia),
                      onRemove: () {
                        setState(() {
                          _selectedMultimediaFile = null;
                          _multimediaUrl = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      (_isSaving ||
                          _isUploadingImage ||
                          _isUploadingDocument ||
                          _isUploadingMultimedia)
                      ? null
                      : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Guardar' : 'Añadir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileSelectionRow extends StatelessWidget {
  final String title;
  final File? selectedFile;
  final String? existingUrl;
  final bool isUploading;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _FileSelectionRow({
    required this.title,
    required this.selectedFile,
    required this.existingUrl,
    required this.isUploading,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedFile != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.basename(selectedFile!.path),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: isUploading ? null : onSelect,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: isUploading ? null : onRemove,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Quitar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (existingUrl != null && existingUrl!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      existingUrl!,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: isUploading ? null : onSelect,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: isUploading ? null : onSelect,
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text('Seleccionar archivo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
        ],
      ),
    );
  }
}
