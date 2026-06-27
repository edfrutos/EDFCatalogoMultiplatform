import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_viewmodel.dart';
import '../../../utils/validators.dart';
import '../../../utils/app_theme.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isAdmin = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AdminViewModel>();
    await vm.createUser(
      username: _usernameCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      isAdmin: _isAdmin,
    );

    if (!mounted) return;

    if (vm.successMessage != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vm.successMessage!),
        behavior: SnackBarBehavior.floating,
      ));
    } else if (vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vm.errorMessage!),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<AdminViewModel>(
      builder: (context, vm, _) {
        return AlertDialog(
          icon: Icon(Icons.person_add_rounded, color: cs.primary, size: 28),
          title: Text('Crear nuevo usuario',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          contentPadding:
              const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    // Fila usuario / nombre
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              hintText: 'juan_perez',
                              prefixIcon:
                                  Icon(Icons.alternate_email_rounded, size: 18),
                            ),
                            validator: Validators.validateUsername,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              hintText: 'Juan Pérez',
                              prefixIcon:
                                  Icon(Icons.badge_rounded, size: 18),
                            ),
                            validator: (v) =>
                                Validators.validateRequired(v,
                                    fieldName: 'El nombre'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'juan@ejemplo.com',
                        prefixIcon: Icon(Icons.email_rounded, size: 18),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        hintText: 'Mínimo 6 caracteres',
                        prefixIcon:
                            const Icon(Icons.lock_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: Validators.validatePassword,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon:
                            const Icon(Icons.lock_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      obscureText: _obscureConfirm,
                      validator: (v) => Validators.validatePasswordMatch(
                          v, _passwordCtrl.text),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleCreate(),
                    ),
                    const SizedBox(height: 14),
                    // Toggle admin
                    InkWell(
                      onTap: () => setState(() => _isAdmin = !_isAdmin),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isAdmin
                              ? cs.tertiaryContainer
                              : cs.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: _isAdmin
                                ? cs.tertiary
                                : cs.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded,
                                size: 20,
                                color: _isAdmin
                                    ? cs.onTertiaryContainer
                                    : cs.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Administrador',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _isAdmin
                                              ? cs.onTertiaryContainer
                                              : cs.onSurface)),
                                  Text(
                                      'Acceso al panel de administración',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: _isAdmin
                                              ? cs.onTertiaryContainer
                                                  .withValues(alpha: 0.75)
                                              : cs.onSurface
                                                  .withValues(alpha: 0.5))),
                                ],
                              ),
                            ),
                            Switch(
                                value: _isAdmin,
                                onChanged: (v) =>
                                    setState(() => _isAdmin = v)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: vm.isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: vm.isLoading ? null : _handleCreate,
              icon: vm.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onPrimary))
                  : const Icon(Icons.person_add_rounded, size: 16),
              label: Text(vm.isLoading ? 'Creando...' : 'Crear usuario'),
            ),
          ],
        );
      },
    );
  }
}
