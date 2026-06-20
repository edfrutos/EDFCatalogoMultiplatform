import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import '../../../models/catalog.dart';
import '../../../models/file_type.dart' as app_file_type;
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../services/s3_service.dart';
import '../../../utils/validators.dart';
import 'multiple_files_section.dart';

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
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  late RowFiles _files;
  bool _isSaving = false;

  // Archivos seleccionados (listas para múltiples archivos)
  List<File> _selectedImageFiles = [];
  List<File> _selectedDocumentFiles = [];
  List<File> _selectedMultimediaFiles = [];

  // URLs existentes
  List<String> _imageUrls = [];
  List<String> _documentUrls = [];
  List<String> _multimediaUrls = [];

  // Títulos personalizados para cada archivo (URL -> Título)
  Map<String, String> _fileTitles = {};

  // Controladores de texto para los títulos (URL -> TextEditingController)
  final Map<String, TextEditingController> _titleControllers = {};

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
    // Inicializar listas de URLs existentes
    _imageUrls = [if (_files.image != null) _files.image!, ..._files.images];
    _documentUrls = [
      if (_files.document != null) _files.document!,
      ..._files.documents,
    ];
    _multimediaUrls = [
      if (_files.multimedia != null) _files.multimedia!,
      ..._files.multimediaFiles,
    ];
    // Inicializar títulos existentes
    _fileTitles = Map<String, String>.from(_files.fileTitles);

    // Debug: verificar títulos cargados
    if (_fileTitles.isNotEmpty) {
      print(
        '📝 AddEditRowDialog - Títulos cargados desde fila existente: $_fileTitles',
      );
    } else {
      print('⚠️ AddEditRowDialog - No hay títulos en la fila existente');
    }

    // Inicializar controladores de títulos para URLs existentes
    final allUrls = [..._imageUrls, ..._documentUrls, ..._multimediaUrls];
    for (final url in allUrls) {
      if (!_titleControllers.containsKey(url)) {
        final title = _fileTitles[url] ?? '';
        _titleControllers[url] = TextEditingController(text: title);
        if (title.isNotEmpty) {
          print(
            '📝 AddEditRowDialog - Controlador inicializado para $url con título: "$title"',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    // Limpiar controladores de títulos
    for (final controller in _titleControllers.values) {
      controller.dispose();
    }
    _titleControllers.clear();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Validar formulario antes de guardar
    if (!_formKey.currentState!.validate()) {
      // Si la validación falla, mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, corrige los errores en el formulario'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = <String, String>{};
    for (final entry in _controllers.entries) {
      data[entry.key] = entry.value.text.trim();
    }

    // Subir archivos si hay alguno seleccionado
    final authViewModel = context.read<AuthViewModel>();
    final userId = authViewModel.currentUser?.id ?? '';

    // Subir imágenes
    if (_selectedImageFiles.isNotEmpty) {
      setState(() {
        _isUploadingImage = true;
      });
      try {
        for (final file in _selectedImageFiles) {
          final url = await S3Service.shared.uploadFile(
            filePath: file.path,
            userId: userId,
            catalogId: widget.catalog.id,
            fileType: app_file_type.FileType.image,
          );
          _imageUrls.add(url);
          // Preservar título si existe para la ruta temporal
          final tempPath = file.path;
          if (_fileTitles.containsKey(tempPath)) {
            final title = _fileTitles.remove(tempPath)!;
            _fileTitles[url] = title;
            // Transferir controlador
            if (_titleControllers.containsKey(tempPath)) {
              final controller = _titleControllers.remove(tempPath)!;
              controller.text = title;
              _titleControllers[url] = controller;
            } else {
              _getOrCreateTitleController(url).text = title;
            }
          } else {
            _getOrCreateTitleController(url);
          }
        }
      } catch (e) {
        _uploadError = 'Error subiendo imagen: $e';
      } finally {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }

    // Subir documentos
    if (_selectedDocumentFiles.isNotEmpty) {
      setState(() {
        _isUploadingDocument = true;
      });
      try {
        for (final file in _selectedDocumentFiles) {
          final url = await S3Service.shared.uploadFile(
            filePath: file.path,
            userId: userId,
            catalogId: widget.catalog.id,
            fileType: app_file_type.FileType.document,
          );
          _documentUrls.add(url);
          // Preservar título si existe para la ruta temporal
          final tempPath = file.path;
          if (_fileTitles.containsKey(tempPath)) {
            final title = _fileTitles.remove(tempPath)!;
            _fileTitles[url] = title;
            // Transferir controlador
            if (_titleControllers.containsKey(tempPath)) {
              final controller = _titleControllers.remove(tempPath)!;
              controller.text = title;
              _titleControllers[url] = controller;
            } else {
              _getOrCreateTitleController(url).text = title;
            }
          } else {
            _getOrCreateTitleController(url);
          }
        }
      } catch (e) {
        _uploadError = 'Error subiendo documento: $e';
      } finally {
        setState(() {
          _isUploadingDocument = false;
        });
      }
    }

    // Subir multimedia
    if (_selectedMultimediaFiles.isNotEmpty) {
      setState(() {
        _isUploadingMultimedia = true;
      });
      try {
        for (final file in _selectedMultimediaFiles) {
          final url = await S3Service.shared.uploadFile(
            filePath: file.path,
            userId: userId,
            catalogId: widget.catalog.id,
            fileType: app_file_type.FileType.multimedia,
          );
          _multimediaUrls.add(url);
          // Preservar título si existe para la ruta temporal
          final tempPath = file.path;
          if (_fileTitles.containsKey(tempPath)) {
            final title = _fileTitles.remove(tempPath)!;
            _fileTitles[url] = title;
            // Transferir controlador
            if (_titleControllers.containsKey(tempPath)) {
              final controller = _titleControllers.remove(tempPath)!;
              controller.text = title;
              _titleControllers[url] = controller;
            } else {
              _getOrCreateTitleController(url).text = title;
            }
          } else {
            _getOrCreateTitleController(url);
          }
        }
      } catch (e) {
        _uploadError = 'Error subiendo multimedia: $e';
      } finally {
        setState(() {
          _isUploadingMultimedia = false;
        });
      }
    }

    // Capturar TODOS los títulos de los controladores antes de guardar
    // Esto asegura que se capturen incluso si el usuario editó pero no se disparó onChanged
    final allUrls = [..._imageUrls, ..._documentUrls, ..._multimediaUrls];
    final finalFileTitles = <String, String>{};
    for (final url in allUrls) {
      if (_titleControllers.containsKey(url)) {
        final title = _titleControllers[url]!.text.trim();
        if (title.isNotEmpty) {
          finalFileTitles[url] = title;
        }
      } else if (_fileTitles.containsKey(url)) {
        // Si no hay controlador pero hay título en el mapa, usarlo
        final title = _fileTitles[url]!.trim();
        if (title.isNotEmpty) {
          finalFileTitles[url] = title;
        }
      }
    }

    // Crear RowFiles con las URLs finales
    // El primer elemento va en el campo singular (retrocompatibilidad), el resto en las listas
    final finalFiles = RowFiles(
      image: _imageUrls.isNotEmpty ? _imageUrls.first : null,
      images: _imageUrls.length > 1 ? _imageUrls.sublist(1) : [],
      document: _documentUrls.isNotEmpty ? _documentUrls.first : null,
      documents: _documentUrls.length > 1 ? _documentUrls.sublist(1) : [],
      multimedia: _multimediaUrls.isNotEmpty ? _multimediaUrls.first : null,
      multimediaFiles: _multimediaUrls.length > 1
          ? _multimediaUrls.sublist(1)
          : [],
      fileTitles: finalFileTitles,
    );

    // Debug: mostrar títulos que se van a guardar
    print('📝 Títulos de archivos a guardar:');
    for (final entry in finalFileTitles.entries) {
      print('   ${entry.key}: "${entry.value}"');
    }

    // Debug: mostrar URLs que se van a guardar
    print('📁 Guardando archivos:');
    print('   Imágenes (${_imageUrls.length}): $_imageUrls');
    print('   Documentos (${_documentUrls.length}): $_documentUrls');
    print('   Multimedia (${_multimediaUrls.length}): $_multimediaUrls');
    print(
      '   RowFiles final: image=${finalFiles.image}, images=${finalFiles.images}',
    );
    print(
      '   RowFiles final: document=${finalFiles.document}, documents=${finalFiles.documents}',
    );
    print(
      '   RowFiles final: multimedia=${finalFiles.multimedia}, multimediaFiles=${finalFiles.multimediaFiles}',
    );

    widget.onSave(data, finalFiles);
    setState(() {
      _isSaving = true;
    });
  }

  Future<void> _selectFile(
    app_file_type.FileType fileType, {
    bool allowMultiple = false,
  }) async {
    file_picker.FilePickerResult? result;

    switch (fileType) {
      case app_file_type.FileType.image:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.image,
          allowMultiple: allowMultiple,
        );
        break;
      case app_file_type.FileType.document:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'txt',
            'rtf',
            'md',
            'markdown',
            'csv',
            'json',
            'xml',
            'log',
          ],
          allowMultiple: allowMultiple,
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
          allowMultiple: allowMultiple,
        );
        break;
      case app_file_type.FileType.multimedia:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.media,
          allowMultiple: allowMultiple,
        );
        break;
      case app_file_type.FileType.other:
        result = await file_picker.FilePicker.platform.pickFiles(
          type: file_picker.FileType.any,
          allowMultiple: allowMultiple,
        );
        break;
    }

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final files = result!.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        switch (fileType) {
          case app_file_type.FileType.image:
            if (allowMultiple) {
              _selectedImageFiles.addAll(files);
            } else {
              _selectedImageFiles = files;
            }
            break;
          case app_file_type.FileType.document:
            if (allowMultiple) {
              _selectedDocumentFiles.addAll(files);
            } else {
              _selectedDocumentFiles = files;
            }
            break;
          case app_file_type.FileType.multimedia:
            if (allowMultiple) {
              _selectedMultimediaFiles.addAll(files);
            } else {
              _selectedMultimediaFiles = files;
            }
            break;
          default:
            break;
        }
        _uploadError = null;
      });
    }
  }

  Future<void> _addUrl(String url, app_file_type.FileType fileType) async {
    setState(() {
      switch (fileType) {
        case app_file_type.FileType.image:
          _imageUrls.add(url);
          break;
        case app_file_type.FileType.document:
          _documentUrls.add(url);
          break;
        case app_file_type.FileType.multimedia:
          _multimediaUrls.add(url);
          break;
        default:
          break;
      }
      // Crear controlador para la nueva URL
      _getOrCreateTitleController(url);
      _uploadError = null;
    });
  }

  void _removeFileOrUrl(int index, app_file_type.FileType fileType) {
    setState(() {
      String? urlToRemove;
      switch (fileType) {
        case app_file_type.FileType.image:
          if (index < _selectedImageFiles.length) {
            _selectedImageFiles.removeAt(index);
          } else {
            final urlIndex = index - _selectedImageFiles.length;
            if (urlIndex < _imageUrls.length) {
              urlToRemove = _imageUrls[urlIndex];
              _imageUrls.removeAt(urlIndex);
            }
          }
          break;
        case app_file_type.FileType.document:
          if (index < _selectedDocumentFiles.length) {
            _selectedDocumentFiles.removeAt(index);
          } else {
            final urlIndex = index - _selectedDocumentFiles.length;
            if (urlIndex < _documentUrls.length) {
              urlToRemove = _documentUrls[urlIndex];
              _documentUrls.removeAt(urlIndex);
            }
          }
          break;
        case app_file_type.FileType.multimedia:
          if (index < _selectedMultimediaFiles.length) {
            _selectedMultimediaFiles.removeAt(index);
          } else {
            final urlIndex = index - _selectedMultimediaFiles.length;
            if (urlIndex < _multimediaUrls.length) {
              urlToRemove = _multimediaUrls[urlIndex];
              _multimediaUrls.removeAt(urlIndex);
            }
          }
          break;
        default:
          break;
      }
      // Eliminar título y controlador asociados si existen
      if (urlToRemove != null) {
        if (_fileTitles.containsKey(urlToRemove)) {
          _fileTitles.remove(urlToRemove);
        }
        if (_titleControllers.containsKey(urlToRemove)) {
          _titleControllers[urlToRemove]!.dispose();
          _titleControllers.remove(urlToRemove);
        }
      }
    });
  }

  void _updateFileTitle(String url, String title) {
    setState(() {
      if (title.trim().isEmpty) {
        _fileTitles.remove(url);
      } else {
        _fileTitles[url] = title.trim();
      }
      // Actualizar el controlador si existe
      if (_titleControllers.containsKey(url)) {
        final controller = _titleControllers[url]!;
        if (controller.text != title) {
          controller.text = title;
          controller.selection = TextSelection.collapsed(offset: title.length);
        }
      }
    });
  }

  TextEditingController _getOrCreateTitleController(String url) {
    if (!_titleControllers.containsKey(url)) {
      _titleControllers[url] = TextEditingController(
        text: _fileTitles[url] ?? '',
      );
    }
    return _titleControllers[url]!;
  }

  String _getFileUrl(int index, app_file_type.FileType fileType) {
    switch (fileType) {
      case app_file_type.FileType.image:
        if (index < _selectedImageFiles.length) {
          return _selectedImageFiles[index].path; // Temporal hasta subir
        } else {
          final urlIndex = index - _selectedImageFiles.length;
          if (urlIndex < _imageUrls.length) {
            return _imageUrls[urlIndex];
          }
        }
        break;
      case app_file_type.FileType.document:
        if (index < _selectedDocumentFiles.length) {
          return _selectedDocumentFiles[index].path; // Temporal hasta subir
        } else {
          final urlIndex = index - _selectedDocumentFiles.length;
          if (urlIndex < _documentUrls.length) {
            return _documentUrls[urlIndex];
          }
        }
        break;
      case app_file_type.FileType.multimedia:
        if (index < _selectedMultimediaFiles.length) {
          return _selectedMultimediaFiles[index].path; // Temporal hasta subir
        } else {
          final urlIndex = index - _selectedMultimediaFiles.length;
          if (urlIndex < _multimediaUrls.length) {
            return _multimediaUrls[urlIndex];
          }
        }
        break;
      default:
        break;
    }
    return '';
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                              helperText: 'Campo requerido',
                              helperMaxLines: 1,
                            ),
                            validator: (value) {
                              // Validación básica - puede extenderse con reglas por columna
                              return Validators.validateRequired(
                                value,
                                fieldName: column,
                              );
                            },
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
                      MultipleFilesSection(
                        title: 'Imagen',
                        fileType: app_file_type.FileType.image,
                        selectedFiles: _selectedImageFiles,
                        existingUrls: _imageUrls,
                        isUploading: _isUploadingImage,
                        fileTitles: _fileTitles,
                        onSelectFile: () =>
                            _selectFile(app_file_type.FileType.image),
                        onSelectMultipleFiles: () => _selectFile(
                          app_file_type.FileType.image,
                          allowMultiple: true,
                        ),
                        onAddUrl: (url) =>
                            _addUrl(url, app_file_type.FileType.image),
                        onRemove: (index) => _removeFileOrUrl(
                          index,
                          app_file_type.FileType.image,
                        ),
                        onUpdateTitle: (url, title) =>
                            _updateFileTitle(url, title),
                        getFileUrl: (index) =>
                            _getFileUrl(index, app_file_type.FileType.image),
                        getTitleController: (url) =>
                            _getOrCreateTitleController(url),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Documento
                      MultipleFilesSection(
                        title: 'Documento',
                        fileType: app_file_type.FileType.document,
                        selectedFiles: _selectedDocumentFiles,
                        existingUrls: _documentUrls,
                        isUploading: _isUploadingDocument,
                        fileTitles: _fileTitles,
                        onSelectFile: () =>
                            _selectFile(app_file_type.FileType.document),
                        onSelectMultipleFiles: () => _selectFile(
                          app_file_type.FileType.document,
                          allowMultiple: true,
                        ),
                        onAddUrl: (url) =>
                            _addUrl(url, app_file_type.FileType.document),
                        onRemove: (index) => _removeFileOrUrl(
                          index,
                          app_file_type.FileType.document,
                        ),
                        onUpdateTitle: (url, title) =>
                            _updateFileTitle(url, title),
                        getFileUrl: (index) =>
                            _getFileUrl(index, app_file_type.FileType.document),
                        getTitleController: (url) =>
                            _getOrCreateTitleController(url),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Multimedia
                      MultipleFilesSection(
                        title: 'Multimedia',
                        fileType: app_file_type.FileType.multimedia,
                        selectedFiles: _selectedMultimediaFiles,
                        existingUrls: _multimediaUrls,
                        isUploading: _isUploadingMultimedia,
                        fileTitles: _fileTitles,
                        onSelectFile: () =>
                            _selectFile(app_file_type.FileType.multimedia),
                        onSelectMultipleFiles: () => _selectFile(
                          app_file_type.FileType.multimedia,
                          allowMultiple: true,
                        ),
                        onAddUrl: (url) =>
                            _addUrl(url, app_file_type.FileType.multimedia),
                        onRemove: (index) => _removeFileOrUrl(
                          index,
                          app_file_type.FileType.multimedia,
                        ),
                        onUpdateTitle: (url, title) =>
                            _updateFileTitle(url, title),
                        getFileUrl: (index) => _getFileUrl(
                          index,
                          app_file_type.FileType.multimedia,
                        ),
                        getTitleController: (url) =>
                            _getOrCreateTitleController(url),
                      ),
                    ],
                  ),
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
