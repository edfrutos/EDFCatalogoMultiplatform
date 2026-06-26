import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/mongo_service.dart';
import '../../services/s3_service.dart';
import '../../services/api_service.dart';
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

  file_picker.PlatformFile? _selectedPlatformFile;
  bool _shouldRemoveImage = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String? _successMessage;
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

  Future<void> _loadPresignedUrl(String? rawUrl) async {
    if (rawUrl == null) {
      if (mounted) setState(() => _presignedImageUrl = null);
      return;
    }
    try {
      final uri = await S3Service().getPresignedUrl(key: rawUrl);
      if (mounted) setState(() => _presignedImageUrl = uri.toString());
    } catch (e) {
      print('❌ Error generando URL pre-firmada: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _errorMessage = null; _successMessage = null; });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;

      if (user == null) {
        setState(() { _errorMessage = 'No hay usuario autenticado'; _isSaving = false; });
        return;
      }

      String? profileImageUrl = user.profileImageUrl;

      if (_shouldRemoveImage && _selectedPlatformFile == null) {
        profileImageUrl = null;
      } else if (_selectedPlatformFile != null) {
        setState(() => _isUploadingImage = true);
        try {
          final pf = _selectedPlatformFile!;
          if (kIsWeb) {
            profileImageUrl = await ApiService.instance.uploadBytes(
              bytes: pf.bytes!,
              fileName: pf.name,
              folder: 'users/${user.id}/catalogs/profile/image',
              contentType: 'image/${pf.extension ?? 'jpeg'}',
            );
          } else {
            profileImageUrl = await S3Service().uploadFile(
              filePath: pf.path!,
              userId: user.id,
              catalogId: 'profile',
              fileType: FileType.image,
            );
          }
          print('✅ Imagen de perfil subida: $profileImageUrl');
        } catch (e) {
          setState(() {
            _errorMessage = 'Error al subir imagen: $e';
            _isSaving = false;
            _isUploadingImage = false;
          });
          return;
        }
        setState(() => _isUploadingImage = false);
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
        'ProfileImageUrl': profileImageUrl,
      };
      await MongoService().updateUser(user.id, updates);
      await authViewModel.reloadCurrentUser();
      await _loadPresignedUrl(profileImageUrl);

      setState(() {
        _successMessage = 'Perfil actualizado correctamente';
        _errorMessage = null;
        _isSaving = false;
      });
      _selectedPlatformFile = null;
      _shouldRemoveImage = false;

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
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

  Future<void> _selectProfileImage() async {
    try {
      file_picker.FilePickerResult? result = await file_picker.FilePicker.platform.pickFiles(
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
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      final isLinux = !kIsWeb && Platform.isLinux;
      final msg = isLinux && e.toString().contains('zenity')
          ? 'Error: zenity no disponible. El selector de archivos puede no funcionar en Docker.'
          : 'Error al seleccionar imagen: $e';
      setState(() => _errorMessage = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _selectedPlatformFile = null;
      _shouldRemoveImage = true;
      _presignedImageUrl = null;
    });
  }

  // Devuelve el ImageProvider correcto según el estado de la imagen
  ImageProvider? _getAvatarImage() {
    if (_selectedPlatformFile != null) {
      if (kIsWeb && _selectedPlatformFile!.bytes != null) {
        return MemoryImage(_selectedPlatformFile!.bytes!);
      } else if (!kIsWeb && _selectedPlatformFile!.path != null) {
        return FileImage(File(_selectedPlatformFile!.path!));
      }
    }
    if (!_shouldRemoveImage && _presignedImageUrl != null) {
      return NetworkImage(_presignedImageUrl!);
    }
    return null;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        final user = authViewModel.currentUser;
        if (user == null) {
          return const Center(child: Text('No hay usuario autenticado'));
        }

        final cs = Theme.of(context).colorScheme;
        final avatarImage = _getAvatarImage();
        final isWide = MediaQuery.of(context).size.width > 800;

        return Scaffold(
          appBar: Navigator.canPop(context)
              ? AppBar(
                  title: Text('Mi perfil',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  centerTitle: false,
                )
              : null,
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Avatar hero ───────────────────────────────────
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Círculo avatar
                              Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primaryContainer,
                                  border: Border.all(
                                      color: cs.outline.withOpacity(0.2),
                                      width: 2),
                                  image: avatarImage != null
                                      ? DecorationImage(
                                          image: avatarImage,
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: avatarImage == null
                                    ? Center(
                                        child: Text(
                                          _getInitials(user.name),
                                          style: GoogleFonts.inter(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              // Botón de edición superpuesto
                              Positioned(
                                bottom: 0,
                                right: -4,
                                child: GestureDetector(
                                  onTap: _selectProfileImage,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primary,
                                      border: Border.all(
                                          color: cs.surface, width: 2),
                                    ),
                                    child: Icon(Icons.camera_alt_rounded,
                                        size: 18, color: cs.onPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nombre y rol
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                user.name,
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: cs.onSurface.withOpacity(0.55)),
                              ),
                              if (user.role != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull),
                                  ),
                                  child: Text(
                                    user.role!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Botones de imagen
                        const SizedBox(height: 16),
                        Center(
                          child: Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isUploadingImage
                                    ? null
                                    : _selectProfileImage,
                                icon: const Icon(Icons.photo_camera_rounded,
                                    size: 16),
                                label: Text(
                                  _selectedPlatformFile != null
                                      ? 'Cambiar foto'
                                      : 'Cambiar foto',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                              ),
                              if ((_selectedPlatformFile != null ||
                                      _presignedImageUrl != null) &&
                                  !_shouldRemoveImage &&
                                  !_isUploadingImage)
                                OutlinedButton.icon(
                                  onPressed: _removeProfileImage,
                                  icon: const Icon(Icons.delete_rounded,
                                      size: 16),
                                  label: Text('Eliminar',
                                      style: GoogleFonts.inter(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cs.error,
                                    side: BorderSide(color: cs.error),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (_isUploadingImage) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: cs.primary),
                              ),
                              const SizedBox(width: 10),
                              Text('Subiendo imagen...',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: cs.onSurface.withOpacity(0.6))),
                            ],
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── Información básica ──────────────────────────
                        _SectionCard(
                          title: 'Información básica',
                          icon: Icons.person_rounded,
                          cs: cs,
                          children: [
                            // Email (no editable)
                            TextFormField(
                              initialValue: user.email,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_rounded),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest
                                    .withOpacity(0.5),
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 14),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _buildField(
                                          controller: _usernameController,
                                          label: 'Nombre de usuario *',
                                          icon: Icons.alternate_email_rounded,
                                          hint: 'Ej: juanp',
                                          autocorrect: false,
                                          validator: (v) => (v == null ||
                                                  v.isEmpty)
                                              ? 'Obligatorio'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildField(
                                          controller: _nameController,
                                          label: 'Nombre para mostrar *',
                                          icon: Icons.badge_rounded,
                                          hint: 'Ej: Juan',
                                          validator: (v) => (v == null ||
                                                  v.isEmpty)
                                              ? 'Obligatorio'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildField(
                                        controller: _usernameController,
                                        label: 'Nombre de usuario *',
                                        icon: Icons.alternate_email_rounded,
                                        hint: 'Ej: juanp',
                                        autocorrect: false,
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'Obligatorio'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        controller: _nameController,
                                        label: 'Nombre para mostrar *',
                                        icon: Icons.badge_rounded,
                                        hint: 'Ej: Juan',
                                        validator: (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'Obligatorio'
                                                : null,
                                      ),
                                    ],
                                  ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Información adicional ───────────────────────
                        _SectionCard(
                          title: 'Información adicional',
                          icon: Icons.info_outline_rounded,
                          cs: cs,
                          children: [
                            _buildField(
                              controller: _fullNameController,
                              label: 'Nombre y apellidos completos',
                              icon: Icons.account_box_rounded,
                              hint: 'Ej: Juan Pérez García',
                            ),
                            const SizedBox(height: 14),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _buildField(
                                          controller: _phoneController,
                                          label: 'Teléfono',
                                          icon: Icons.phone_rounded,
                                          hint: 'Ej: +34 600 000 000',
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildField(
                                          controller: _occupationController,
                                          label: 'Ocupación',
                                          icon: Icons.work_rounded,
                                          hint: 'Ej: Desarrollador',
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildField(
                                        controller: _phoneController,
                                        label: 'Teléfono',
                                        icon: Icons.phone_rounded,
                                        hint: 'Ej: +34 600 000 000',
                                        keyboardType: TextInputType.phone,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        controller: _occupationController,
                                        label: 'Ocupación',
                                        icon: Icons.work_rounded,
                                        hint: 'Ej: Desarrollador',
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 14),
                            _buildField(
                              controller: _companyController,
                              label: 'Empresa',
                              icon: Icons.business_rounded,
                              hint: 'Ej: Mi Empresa S.L.',
                            ),
                            const SizedBox(height: 14),
                            _buildField(
                              controller: _addressController,
                              label: 'Dirección postal',
                              icon: Icons.location_on_rounded,
                              maxLines: 3,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Mensajes de estado ──────────────────────────
                        if (_errorMessage != null) ...[
                          _StatusBanner(
                            message: _errorMessage!,
                            isError: true,
                            cs: cs,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_successMessage != null) ...[
                          _StatusBanner(
                            message: _successMessage!,
                            isError: false,
                            cs: cs,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Botón guardar ───────────────────────────────
                        FilledButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : Text(
                                  'Guardar cambios',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    bool autocorrect = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      autocorrect: autocorrect,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

// ── Tarjeta de sección ────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.cs,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de sección
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outlineVariant),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner de estado (error / éxito) ─────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final ColorScheme cs;

  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError ? cs.errorContainer : cs.tertiaryContainer;
    final fg = isError ? cs.onErrorContainer : cs.onTertiaryContainer;
    final icon = isError ? Icons.error_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                  fontSize: 13, color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
