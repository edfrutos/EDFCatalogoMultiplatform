import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/user.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../services/s3_service.dart';
import '../../models/file_type.dart';

class AdminUserDetailView extends StatefulWidget {
  final User user;

  const AdminUserDetailView({super.key, required this.user});

  @override
  State<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends State<AdminUserDetailView> {
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _nameController;
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _occupationController;

  late bool _isAdmin;
  late bool _isActive;
  bool _isEditing = false;

  // Foto de perfil
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  bool _shouldRemoveImage = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _emailController = TextEditingController(text: widget.user.email);
    _usernameController = TextEditingController(text: widget.user.username);
    _nameController = TextEditingController(text: widget.user.name);
    _fullNameController = TextEditingController(
      text: widget.user.fullName ?? '',
    );
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _companyController = TextEditingController(text: widget.user.company ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _occupationController = TextEditingController(
      text: widget.user.occupation ?? '',
    );
    _isAdmin = widget.user.isAdmin;
    _isActive = widget.user.isActive ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _emailController.text != widget.user.email ||
        _usernameController.text != widget.user.username ||
        _nameController.text != widget.user.name ||
        _fullNameController.text != (widget.user.fullName ?? '') ||
        _phoneController.text != (widget.user.phone ?? '') ||
        _companyController.text != (widget.user.company ?? '') ||
        _addressController.text != (widget.user.address ?? '') ||
        _occupationController.text != (widget.user.occupation ?? '') ||
        _isAdmin != widget.user.isAdmin ||
        _isActive != (widget.user.isActive ?? true) ||
        _selectedImageFile != null ||
        _shouldRemoveImage;
  }

  Future<void> _handleSave() async {
    if (!_hasChanges) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    final viewModel = context.read<AdminViewModel>();

    String? profileImageUrl = widget.user.profileImageUrl;

    // Si se debe eliminar la imagen, establecer como null
    if (_shouldRemoveImage && _selectedImageFile == null) {
      profileImageUrl = null;
    }
    // Subir imagen si hay una nueva seleccionada
    else if (_selectedImageFile != null) {
      setState(() {
        _isUploadingImage = true;
      });

      try {
        final s3Service = S3Service();
        profileImageUrl = await s3Service.uploadFile(
          filePath: _selectedImageFile!.path,
          userId: widget.user.id,
          catalogId:
              'profile', // Usar 'profile' como catalogId para fotos de perfil
          fileType: FileType.image,
        );

        print('✅ Imagen de perfil subida: $profileImageUrl');
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

    final updatedUser = User(
      id: widget.user.id,
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      name: _nameController.text.trim(),
      isAdmin: _isAdmin,
      fullName: _fullNameController.text.trim().isEmpty
          ? null
          : _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      company: _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      isActive: _isActive,
      profileImageUrl: profileImageUrl,
      createdAt: widget.user.createdAt,
      lastLoginAt: widget.user.lastLoginAt,
    );

    await viewModel.updateUser(updatedUser);

    // Limpiar archivo seleccionado y flags después de guardar
    setState(() {
      _selectedImageFile = null;
      _shouldRemoveImage = false;
      _isEditing = false;
    });
  }

  /// Seleccionar foto de perfil usando file_picker
  Future<void> _selectProfileImage() async {
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
          _shouldRemoveImage = false; // Si selecciona nueva, no eliminar
        });
        print('✅ Imagen seleccionada: $filePath');
      } else {
        print('⚠️ No se seleccionó ninguna imagen');
      }
    } catch (e) {
      print('❌ Error al seleccionar imagen: $e');
      if (mounted) {
        final isLinux = !kIsWeb && Platform.isLinux;
        final errorMessage = isLinux && e.toString().contains('zenity')
            ? 'Error: zenity no está disponible. En Docker, el selector de archivos puede no funcionar. Por favor, reconstruye la imagen Docker o usa la aplicación fuera de Docker.'
            : 'Error al seleccionar imagen: $e';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Eliminar foto de perfil
  void _removeProfileImage() {
    setState(() {
      _selectedImageFile = null;
      _shouldRemoveImage = true; // Marcar que se debe eliminar la imagen actual
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalles del Usuario'),
            Text(
              widget.user.email,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () {
                _initializeControllers();
                setState(() {
                  _isEditing = false;
                  _selectedImageFile = null;
                  _shouldRemoveImage = false;
                });
              },
              child: const Text('Cancelar'),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing
                ? _handleSave
                : () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar con foto de perfil
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      // Imagen de perfil o placeholder
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: _selectedImageFile != null
                            ? FileImage(_selectedImageFile!)
                            : widget.user.profileImageUrl != null
                            ? CachedNetworkImageProvider(
                                widget.user.profileImageUrl!,
                              )
                            : null,
                        child:
                            _selectedImageFile == null &&
                                widget.user.profileImageUrl == null
                            ? Text(
                                widget.user.name.isNotEmpty
                                    ? widget.user.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      // Botón de editar foto (solo en modo edición)
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _isUploadingImage
                                  ? null
                                  : _selectProfileImage,
                              tooltip: 'Cambiar foto',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Botones de acción (solo en modo edición)
                  if (_isEditing) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingImage
                              ? null
                              : _selectProfileImage,
                          icon: Icon(Icons.photo_library, size: 18),
                          label: Text('Seleccionar Foto'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                        if ((_selectedImageFile != null ||
                                widget.user.profileImageUrl != null) &&
                            !_isUploadingImage) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _removeProfileImage,
                            icon: Icon(Icons.delete, size: 18),
                            label: Text('Eliminar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Indicador de carga de imagen
                    if (_isUploadingImage) ...[
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Subiendo imagen...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Edit/View Toggle
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('Ver')),
                ButtonSegment(value: true, label: Text('Editar')),
              ],
              selected: {_isEditing},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isEditing = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            // Form Fields
            if (_isEditing) ...[
              _buildEditableSection('Rol', Icons.admin_panel_settings, [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text('Usuario Normal')),
                    ButtonSegment(value: true, label: Text('Administrador')),
                  ],
                  selected: {_isAdmin},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _isAdmin = selection.first;
                    });
                  },
                ),
              ]),
              const SizedBox(height: 16),
              _buildEditableSection('Estado', Icons.circle, [
                SwitchListTile(
                  title: const Text('Usuario Activo'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ]),
            ] else ...[
              _buildReadOnlySection('Rol', Icons.admin_panel_settings, [
                Chip(
                  label: Text(_isAdmin ? 'Administrador' : 'Usuario Normal'),
                  avatar: Icon(
                    _isAdmin ? Icons.admin_panel_settings : Icons.person,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _buildReadOnlySection('Estado', Icons.circle, [
                Chip(
                  label: Text(_isActive ? 'Activo' : 'Inactivo'),
                  avatar: Icon(
                    _isActive ? Icons.check_circle : Icons.circle_notifications,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              'Email',
              Icons.email,
              _emailController,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Usuario',
              Icons.person,
              _usernameController,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Nombre',
              Icons.badge,
              _nameController,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Nombre Completo',
              Icons.account_box,
              _fullNameController,
              enabled: _isEditing,
              optional: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Teléfono',
              Icons.phone,
              _phoneController,
              enabled: _isEditing,
              optional: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Empresa',
              Icons.business,
              _companyController,
              enabled: _isEditing,
              optional: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Ocupación',
              Icons.work,
              _occupationController,
              enabled: _isEditing,
              optional: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Dirección',
              Icons.location_on,
              _addressController,
              enabled: _isEditing,
              optional: true,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool enabled = true,
    bool optional = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label${optional ? ' (Opcional)' : ''}',
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildEditableSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlySection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
