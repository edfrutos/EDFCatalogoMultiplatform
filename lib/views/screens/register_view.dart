import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/validators.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegistering = false;
  String? _message;
  bool _isError = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _passwordsMatch =>
      _passwordController.text == _confirmPasswordController.text;

  bool get _isFormValid =>
      _usernameController.text.isNotEmpty &&
      _nameController.text.isNotEmpty &&
      _emailController.text.isNotEmpty &&
      _passwordController.text.length >= 6 &&
      _passwordsMatch;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isRegistering = true; _message = null; });

    final authViewModel = context.read<AuthViewModel>();
    final result = await authViewModel.register(
      username: _usernameController.text.trim(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isRegistering = false);

    if (result && mounted) {
      setState(() { _isError = false; _message = 'Cuenta creada. Iniciando sesión...'; });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else if (mounted) {
      setState(() {
        _isError = true;
        _message = authViewModel.errorMessage ?? 'Error al crear la cuenta';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cerrar',
        ),
        title: Text('Crear cuenta',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icono + subtítulo
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge),
                          ),
                          child: Icon(Icons.person_add_rounded,
                              size: 32, color: cs.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Regístrate en EDF Catálogo',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Completa los datos para crear tu cuenta',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Campos ────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de usuario *',
                                prefixIcon:
                                    Icon(Icons.alternate_email_rounded),
                              ),
                              enabled: !_isRegistering,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              validator: Validators.validateUsername,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre para mostrar *',
                                prefixIcon: Icon(Icons.badge_rounded),
                              ),
                              enabled: !_isRegistering,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              validator: (value) =>
                                  Validators.validateRequired(value,
                                      fieldName: 'Nombre'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                        enabled: !_isRegistering,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        validator: Validators.validateEmail,
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña (mín. 6 caracteres) *',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        enabled: !_isRegistering,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            Validators.validatePassword(v, minLength: 6),
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña *',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                          // Muestra indicador si no coinciden
                          suffixText:
                              _confirmPasswordController.text.isNotEmpty &&
                                      !_passwordsMatch
                                  ? '✗'
                                  : (_confirmPasswordController.text
                                              .isNotEmpty &&
                                          _passwordsMatch
                                      ? '✓'
                                      : null),
                          suffixStyle: TextStyle(
                            color: _passwordsMatch
                                ? Colors.green
                                : cs.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        enabled: !_isRegistering,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleRegister(),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => Validators.validatePasswordMatch(
                            v, _passwordController.text),
                      ),

                      // Aviso de contraseñas no coincidentes
                      if (_confirmPasswordController.text.isNotEmpty &&
                          !_passwordsMatch) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_rounded,
                                  color: cs.onErrorContainer, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Las contraseñas no coinciden',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: cs.onErrorContainer),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Mensaje de estado
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isError
                                ? cs.errorContainer
                                : cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isError
                                    ? Icons.error_rounded
                                    : Icons.check_circle_rounded,
                                color: _isError
                                    ? cs.onErrorContainer
                                    : cs.onTertiaryContainer,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _message!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _isError
                                        ? cs.onErrorContainer
                                        : cs.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Botón de registro
                      if (_isRegistering)
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: cs.primary),
                              const SizedBox(height: 10),
                              Text('Creando cuenta...',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(alpha: 0.6))),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: _isFormValid ? _handleRegister : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium),
                            ),
                          ),
                          child: Text(
                            'Crear cuenta',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
