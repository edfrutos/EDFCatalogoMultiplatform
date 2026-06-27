import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/validators.dart';
import 'reset_password_view.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _message;
  bool _isError = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSending = true; _message = null; });

    final authViewModel = context.read<AuthViewModel>();
    final result = await authViewModel.requestPasswordReset(
        _emailController.text.trim());

    setState(() => _isSending = false);

    if (result && mounted) {
      setState(() {
        _isError = false;
        _message = 'Código enviado. Revisa tu email.';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordView(
                  email: _emailController.text.trim()),
            ),
          );
        }
      });
    } else if (mounted) {
      setState(() {
        _isError = true;
        _message = authViewModel.errorMessage ??
            'Error al enviar el código. Verifica el email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Recuperar contraseña',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icono decorativo
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXL),
                        ),
                        child: Icon(Icons.lock_reset_rounded,
                            size: 40, color: cs.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Recupera tu contraseña',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ingresa tu email y te enviaremos un código para restablecer tu contraseña.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Campo de email
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_isSending,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _sendResetEmail(),
                        validator: Validators.validateEmail,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ),

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
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isError
                                  ? Icons.error_rounded
                                  : Icons.mark_email_read_rounded,
                              color: _isError
                                  ? cs.onErrorContainer
                                  : cs.onTertiaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _message!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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

                    // Botón enviar
                    if (_isSending)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: cs.primary),
                            const SizedBox(height: 10),
                            Text(
                              'Enviando código...',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _sendResetEmail,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Enviar código',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Volver al inicio de sesión
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_rounded,
                            size: 16, color: cs.primary),
                        label: Text(
                          'Volver al inicio de sesión',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: cs.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
