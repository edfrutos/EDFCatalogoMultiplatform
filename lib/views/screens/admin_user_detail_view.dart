import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import '../../models/user.dart';
import '../../models/file_type.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../services/s3_service.dart';
import '../../services/api_service.dart';
import 'admin_user_catalogs_view.dart';

class AdminUserDetailView extends StatefulWidget {
  final User user;
  const AdminUserDetailView({super.key, required this.user});

  @override
  State<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends State<AdminUserDetailView> {
  late TextEditingController _emailCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _fullNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _occupationCtrl;

  late bool _isAdmin;
  late bool _isActive;
  bool _isEditing = false;
  bool _isSaving = false;

  file_picker.PlatformFile? _selectedPlatformFile;
  bool _isUploadingImage = false;
  bool _shouldRemoveImage = false;
  String? _presignedImageUrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPresignedUrl(widget.user.profileImageUrl);
  }

  void _initControllers() {
    _emailCtrl = TextEditingController(text: widget.user.email);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _nameCtrl = TextEditingController(text: widget.user.name);
    _fullNameCtrl = TextEditingController(text: widget.user.fullName ?? '');
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _companyCtrl = TextEditingController(text: widget.user.company ?? '');
    _addressCtrl = TextEditingController(text: widget.user.address ?? '');
    _occupationCtrl = TextEditingController(text: widget.user.occupation ?? '');
    _isAdmin = widget.user.isAdmin;
    _isActive = widget.user.isActive ?? true;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _addressCtrl.dispose();
    _occupationCtrl.dispose();
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
    } catch (_) {}
  }

  bool get _hasChanges =>
      _emailCtrl.text != widget.user.email ||
      _usernameCtrl.text != widget.user.username ||
      _nameCtrl.text != widget.user.name ||
      _fullNameCtrl.text != (widget.user.fullName ?? '') ||
      _phoneCtrl.text != (widget.user.phone ?? '') ||
      _companyCtrl.text != (widget.user.company ?? '') ||
      _addressCtrl.text != (widget.user.address ?? '') ||
      _occupationCtrl.text != (widget.user.occupation ?? '') ||
      _isAdmin != widget.user.isAdmin ||
      _isActive != (widget.user.isActive ?? true) ||
      _selectedPlatformFile != null ||
      _shouldRemoveImage;

  Future<void> _handleSave() async {
    if (!_hasChanges) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);
    final vm = context.read<AdminViewModel>();
    String? profileImageUrl = widget.user.profileImageUrl;

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
            folder: 'users/${widget.user.id}/catalogs/profile/image',
            contentType: 'image/${pf.extension ?? 'jpeg'}',
          );
        } else {
          profileImageUrl = await S3Service().uploadFile(
            filePath: pf.path!,
            userId: widget.user.id,
            catalogId: 'profile',
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

    final updated = User(
      id: widget.user.id,
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      isAdmin: _isAdmin,
      fullName: _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim().isEmpty ? null : _occupationCtrl.text.trim(),
      isActive: _isActive,
      profileImageUrl: profileImageUrl,
      createdAt: widget.user.createdAt,
      lastLoginAt: widget.user.lastLoginAt,
    );

    await vm.updateUser(updated);
    await _loadPresignedUrl(profileImageUrl);

    if (mounted) {
      setState(() {
        _selectedPlatformFile = null;
        _shouldRemoveImage = false;
        _isEditing = false;
        _isSaving = false;
      });
    }
  }

  Future<void> _selectProfileImage() async {
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

  void _removeProfileImage() => setState(() {
        _selectedPlatformFile = null;
        _shouldRemoveImage = true;
        _presignedImageUrl = null;
      });

  ImageProvider? _getAvatarImage() {
    if (_selectedPlatformFile != null) {
      if (kIsWeb && _selectedPlatformFile!.bytes != null) {
        return MemoryImage(_selectedPlatformFile!.bytes!);
      } else if (!kIsWeb && _selectedPlatformFile!.path != null) {
        return FileImage(File(_selectedPlatformFile!.path!) as dynamic)
            as ImageProvider;
      }
    }
    if (_presignedImageUrl != null && !_shouldRemoveImage) {
      return CachedNetworkImageProvider(_presignedImageUrl!);
    }
    return null;
  }

  String _initials() {
    final n = widget.user.name.trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Consumer<AdminViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detalles del usuario',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                Text(widget.user.email,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ],
            ),
            actions: [
              if (_isEditing)
                TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _initControllers();
                          setState(() {
                            _isEditing = false;
                            _selectedPlatformFile = null;
                            _shouldRemoveImage = false;
                          });
                        },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar'),
                ),
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Editar',
                  onPressed: () => setState(() => _isEditing = true),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatar ────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: cs.primaryContainer,
                                backgroundImage: _getAvatarImage(),
                                child: _getAvatarImage() == null
                                    ? Text(_initials(),
                                        style: GoogleFonts.inter(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onPrimaryContainer))
                                    : null,
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _isUploadingImage
                                        ? null
                                        : _selectProfileImage,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: cs.surface, width: 3),
                                      ),
                                      child: Icon(Icons.camera_alt_rounded,
                                          size: 18, color: cs.onPrimary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(widget.user.name,
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(widget.user.email,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.55))),
                          const SizedBox(height: 10),
                          // Badges
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.user.isAdmin)
                                _Chip(
                                    label: 'Admin',
                                    icon: Icons.admin_panel_settings_rounded,
                                    bg: cs.tertiaryContainer,
                                    fg: cs.onTertiaryContainer),
                              if (!(widget.user.isActive ?? true))
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _Chip(
                                      label: 'Inactivo',
                                      icon: Icons.block_rounded,
                                      bg: cs.errorContainer,
                                      fg: cs.onErrorContainer),
                                ),
                            ],
                          ),
                          // Botón quitar foto
                          if (_isEditing &&
                              (_selectedPlatformFile != null ||
                                  (widget.user.profileImageUrl != null &&
                                      !_shouldRemoveImage))) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _removeProfileImage,
                              icon: Icon(Icons.delete_rounded,
                                  size: 16, color: cs.error),
                              label: Text('Quitar foto',
                                  style: GoogleFonts.inter(color: cs.error)),
                              style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cs.error)),
                            ),
                          ],
                          if (_isUploadingImage) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary)),
                                const SizedBox(width: 8),
                                Text('Subiendo imagen...',
                                    style: GoogleFonts.inter(fontSize: 12)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Rol y estado ──────────────────────────────────────
                    _SectionCard(
                      title: 'Rol y estado',
                      icon: Icons.verified_user_rounded,
                      cs: cs,
                      child: Column(
                        children: [
                          // Rol
                          Row(children: [
                            Icon(Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Rol',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: cs.onSurface.withValues(alpha: 0.6)))),
                          ]),
                          const SizedBox(height: 8),
                          _isEditing
                              ? SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                        value: false,
                                        label: Text('Usuario'),
                                        icon: Icon(Icons.person_rounded,
                                            size: 16)),
                                    ButtonSegment(
                                        value: true,
                                        label: Text('Administrador'),
                                        icon: Icon(
                                            Icons.admin_panel_settings_rounded,
                                            size: 16)),
                                  ],
                                  selected: {_isAdmin},
                                  onSelectionChanged: (s) =>
                                      setState(() => _isAdmin = s.first),
                                )
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: _Chip(
                                    label: _isAdmin
                                        ? 'Administrador'
                                        : 'Usuario normal',
                                    icon: _isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.person_rounded,
                                    bg: _isAdmin
                                        ? cs.tertiaryContainer
                                        : cs.secondaryContainer,
                                    fg: _isAdmin
                                        ? cs.onTertiaryContainer
                                        : cs.onSecondaryContainer,
                                  ),
                                ),
                          const SizedBox(height: 14),
                          // Estado activo
                          _isEditing
                              ? SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Usuario activo',
                                      style: GoogleFonts.inter(fontSize: 14)),
                                  subtitle: Text(
                                      _isActive
                                          ? 'Puede iniciar sesión'
                                          : 'No puede iniciar sesión',
                                      style: GoogleFonts.inter(fontSize: 12)),
                                  value: _isActive,
                                  onChanged: (v) =>
                                      setState(() => _isActive = v),
                                )
                              : Row(
                                  children: [
                                    Icon(
                                        _isActive
                                            ? Icons.check_circle_rounded
                                            : Icons.block_rounded,
                                        size: 18,
                                        color: _isActive
                                            ? Colors.green
                                            : cs.error),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isActive
                                          ? 'Cuenta activa'
                                          : 'Cuenta inactiva',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: _isActive
                                              ? Colors.green
                                              : cs.error),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Información de cuenta ─────────────────────────────
                    _SectionCard(
                      title: 'Información de cuenta',
                      icon: Icons.manage_accounts_rounded,
                      cs: cs,
                      child: isWide
                          ? Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: _Field(
                                            label: 'Email',
                                            icon: Icons.email_rounded,
                                            ctrl: _emailCtrl,
                                            enabled: _isEditing,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            cs: cs)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: _Field(
                                            label: 'Usuario',
                                            icon: Icons.alternate_email_rounded,
                                            ctrl: _usernameCtrl,
                                            enabled: _isEditing,
                                            cs: cs)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: _Field(
                                            label: 'Nombre',
                                            icon: Icons.badge_rounded,
                                            ctrl: _nameCtrl,
                                            enabled: _isEditing,
                                            cs: cs)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: _Field(
                                            label: 'Nombre completo',
                                            icon: Icons.account_box_rounded,
                                            ctrl: _fullNameCtrl,
                                            enabled: _isEditing,
                                            optional: true,
                                            cs: cs)),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _Field(
                                    label: 'Email',
                                    icon: Icons.email_rounded,
                                    ctrl: _emailCtrl,
                                    enabled: _isEditing,
                                    keyboardType: TextInputType.emailAddress,
                                    cs: cs),
                                const SizedBox(height: 14),
                                _Field(
                                    label: 'Usuario',
                                    icon: Icons.alternate_email_rounded,
                                    ctrl: _usernameCtrl,
                                    enabled: _isEditing,
                                    cs: cs),
                                const SizedBox(height: 14),
                                _Field(
                                    label: 'Nombre',
                                    icon: Icons.badge_rounded,
                                    ctrl: _nameCtrl,
                                    enabled: _isEditing,
                                    cs: cs),
                                const SizedBox(height: 14),
                                _Field(
                                    label: 'Nombre completo',
                                    icon: Icons.account_box_rounded,
                                    ctrl: _fullNameCtrl,
                                    enabled: _isEditing,
                                    optional: true,
                                    cs: cs),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),

                    // ── Datos de contacto ─────────────────────────────────
                    _SectionCard(
                      title: 'Datos de contacto',
                      icon: Icons.contact_phone_rounded,
                      cs: cs,
                      child: Column(
                        children: [
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _Field(
                                        label: 'Teléfono',
                                        icon: Icons.phone_rounded,
                                        ctrl: _phoneCtrl,
                                        enabled: _isEditing,
                                        optional: true,
                                        keyboardType: TextInputType.phone,
                                        cs: cs)),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: _Field(
                                        label: 'Ocupación',
                                        icon: Icons.work_rounded,
                                        ctrl: _occupationCtrl,
                                        enabled: _isEditing,
                                        optional: true,
                                        cs: cs)),
                              ],
                            )
                          else ...[
                            _Field(
                                label: 'Teléfono',
                                icon: Icons.phone_rounded,
                                ctrl: _phoneCtrl,
                                enabled: _isEditing,
                                optional: true,
                                keyboardType: TextInputType.phone,
                                cs: cs),
                            const SizedBox(height: 14),
                            _Field(
                                label: 'Ocupación',
                                icon: Icons.work_rounded,
                                ctrl: _occupationCtrl,
                                enabled: _isEditing,
                                optional: true,
                                cs: cs),
                          ],
                          const SizedBox(height: 14),
                          _Field(
                              label: 'Empresa',
                              icon: Icons.business_rounded,
                              ctrl: _companyCtrl,
                              enabled: _isEditing,
                              optional: true,
                              cs: cs),
                          const SizedBox(height: 14),
                          _Field(
                              label: 'Dirección',
                              icon: Icons.location_on_rounded,
                              ctrl: _addressCtrl,
                              enabled: _isEditing,
                              optional: true,
                              maxLines: 2,
                              cs: cs),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Catálogos del usuario ─────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminUserCatalogsView(user: widget.user),
                        ),
                      ),
                      icon: const Icon(Icons.library_books_rounded),
                      label: const Text('Ver catálogos del usuario'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),

                    // ── Guardar ────────────────────────────────────────────
                    if (_isEditing) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: (_isSaving || _isUploadingImage)
                            ? null
                            : _handleSave,
                        icon: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving
                            ? 'Guardando...'
                            : 'Guardar cambios'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final ColorScheme cs;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController ctrl;
  final bool enabled;
  final bool optional;
  final TextInputType? keyboardType;
  final int maxLines;
  final ColorScheme cs;

  const _Field({
    required this.label,
    required this.icon,
    required this.ctrl,
    required this.cs,
    this.enabled = true,
    this.optional = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: optional ? '$label (opcional)' : label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  const _Chip({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
