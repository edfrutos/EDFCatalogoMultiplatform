import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/mongo_service.dart';
import '../../services/s3_service.dart';
import '../../models/file_type.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();

  File? _selectedImageFile;
  bool _shouldRemoveImage = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String? _successMessage;

  // URL pre-firmada para mostrar la imagen de perfil
  String? _presignedImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        _usernameController.text = user.username;
        _nameController.text = user.name;
        _fullNameController.text = user.fullName ?? '';
        _phoneController.text = user.phone ?? '';
        _companyController.text = user.company ?? '';
        _occupationController.text = user.occupation ?? '';
        _addressController.text = user.address ?? '';
        _loadPresignedUrl(user.profileImageUrl);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  /// Genera una URL pre-firmada para mostrar la imagen desde S3
  Future<void> _loadPresignedUrl(String? rawUrl) async {
    if (rawUrl == null) {
      if (mounted) setState(() => _presignedImageUrl = null);
      return;
    }
    try {
      final uri = await S3Service().getPresignedUrl(key: rawUrl);
      if (mounted) {
        setState(() => _presignedImageUrl = uri.toString());
      }
    } catch (e) {
      print('❌ Error generando URL pre-firmada: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isSaving = false;
        });
        return;
      }

      String? profileImageUrl = user.profileImageUrl;

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
            userId: user.id,
            catalogId: 'profile',
            fileType: FileType.image,
          );

          print('✅ Imagen de perfil subida: $profileImageUrl');
        } catch (e) {
          setState(() {
            _errorMessage = 'Error al subir imagen: $e';
            _isSaving = false;
            _isUploadingImage = false;
          });
          return;
        }

        setState(() {
          _isUploadingImage = false;
        });
      }

      final updates = <String, dynamic>{
        'Username': _usernameController.text.trim(),
        'Name': _nameController.text.trim(),
        if (_fullNameController.text.trim().isNotEmpty)
          'FullName': _fullNameController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'Phone': _phoneController.text.trim(),
        if (_companyController.text.trim().isNotEmpty)
          'Company': _companyController.text.trim(),
        if (_addressController.text.trim().isNotEmpty)
          'Address': _addressController.text.trim(),
        if (_occupationController.text.trim().isNotEmpty)
          'Occupation': _occupationController.text.trim(),
        // Actualizar URL de imagen de perfil (puede ser null si se eliminó)
        'ProfileImageUrl': profileImageUrl,
      };
      await MongoService().updateUser(user.id, updates);

      // Recargar usuario actualizado
      await authViewModel.reloadCurrentUser();

      // Recargar URL pre-firmada con la nueva imagen
      await _loadPresignedUrl(profileImageUrl);

      setState(() {
        _successMessage = 'Perfil actualizado correctamente';
        _errorMessage = null;
        _isSaving = false;
      });

      // Limpiar archivo seleccionado y flags después de guardar
      _selectedImageFile = null;
      _shouldRemoveImage = false;

      // Limpiar mensaje de éxito después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: $e';
        _successMessage = null;
        _isSaving = false;
        _isUploadingImage = false;
      });
    }
  }

  /// Seleccionar foto de perfil usando file_picker (mejor para desktop)
  Future<void> _selectProfileImage() async {
    try {
      file_picker.FilePickerResult? result = await file_picker
          .FilePicker
          .platform
          .pickFiles(
            type: file_picker.FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'],
            allowMultiple: false,
            withData: false,
            withReadStream: false,
          );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        setState(() {
          _selectedImageFile = File(filePath);
          _shouldRemoveImage = false;
          _errorMessage = null;
        });
        print('✅ Imagen seleccionada: $filePath');
      } else {
        print('⚠️ No se seleccionó ninguna imagen');
      }
    } catch (e) {
      print('❌ Error al seleccionar imagen: $e');
      final isLinux = !kIsWeb && Platform.isLinux;
      final errorMessage = isLinux && e.toString().contains('zenity')
          ? 'Error: zenity no está disponible. En Docker, el selector de archivos puede no funcionar. Por favor, reconstruye la imagen Docker o usa la aplicación fuera de Docker.'
          : 'Error al seleccionar imagen: $e';

      setState(() {
        _errorMessage = errorMessage;
      });
      if (mounted) {
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
      _shouldRemoveImage = true;
      _presignedImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        final user = authViewModel.currentUser;

        if (user == null) {
          return const Center(child: Text('No hay usuario autenticado'));
        }

        return Scaffold(
          appBar: Navigator.canPop(context)
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Volver',
                  ),
                  title: const Text('Perfil de Usuario'),
                  centerTitle: true,
                )
              : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Foto de perfil
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            // Imagen de perfil o placeholder
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _selectedImageFile != null
                                  ? FileImage(_selectedImageFile!)
                                        as ImageProvider
                                  : (_presignedImageUrl != null &&
                                        !_shouldRemoveImage)
                                  ? CachedNetworkImageProvider(
                                      _presignedImageUrl!,
                                    )
                                  : null,
                              child:
                                  _selectedImageFile == null &&
                                      (_presignedImageUrl == null ||
                                          _shouldRemoveImage)
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 50,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : null,
                            ),
                            // Botón de editar foto
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
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
                        // Botones de acción
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isUploadingImage
                                  ? null
                                  : _selectProfileImage,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Seleccionar Foto'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            if ((_selectedImageFile != null ||
                                    user.profileImageUrl != null) &&
                                !_isUploadingImage) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _removeProfileImage,
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('Eliminar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Indicador de carga de imagen
                        if (_isUploadingImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Subiendo imagen...'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  // Información básica
                  const Text(
                    'Información Básica',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email (no editable)
                  TextFormField(
                    initialValue: user.email,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario *',
                      hintText: 'Ej: juanp',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    autocorrect: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El nombre de usuario es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre para Mostrar *',
                      hintText: 'Ej: Juan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  // Información adicional
                  const Text(
                    'Información Adicional (Opcional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre y Apellidos Completos',
                      hintText: 'Ej: Juan Pérez García',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_box),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      hintText: 'Ej: +34 600 000 000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Empresa',
                      hintText: 'Ej: Mi Empresa S.L.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _occupationController,
                    decoration: const InputDecoration(
                      labelText: 'Ocupación',
                      hintText: 'Ej: Desarrollador',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección Postal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  // Mensajes
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  // Botón guardar
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar Cambios'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
