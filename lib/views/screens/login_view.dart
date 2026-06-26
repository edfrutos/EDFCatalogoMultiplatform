import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/edf_logo.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';
import 'contact_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberPassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    final authViewModel = context.read<AuthViewModel>();
    await authViewModel.signIn(
      emailOrUsername: _emailOrUsernameController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberPassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: cs.surface,
      body: isWide ? _buildWideLayout(cs) : _buildNarrowLayout(cs),
    );
  }

  Widget _buildWideLayout(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withOpacity(0.75),
                  cs.secondary.withOpacity(0.6),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _DecorativePattern(color: Colors.white)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EdfLogoStacked(iconSize: 88, color: Colors.white),
                        const SizedBox(height: 32),
                        Text(
                          'Gestión de catálogos\nmultiplataforma',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildForm(cs),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(32, 72, 32, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primary, cs.primary.withOpacity(0.85)],
                  ),
                ),
                child: Column(
                  children: [
                    EdfLogoIcon(size: 68, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'EDF Catálogo',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestión de catálogos',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildForm(cs),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenido',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Inicia sesión para continuar',
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailOrUsernameController,
            decoration: const InputDecoration(
              labelText: 'Email o nombre de usuario',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu email o usuario' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSignIn(),
            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberPassword,
                  onChanged: (v) => setState(() => _rememberPassword = v ?? true),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Text('Recordar sesión',
                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForgotPasswordView()),
                ),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Text('¿Olvidaste la contraseña?',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: cs.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer<AuthViewModel>(
            builder: (context, vm, _) {
              if (vm.errorMessage == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: cs.onErrorContainer, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(vm.errorMessage!,
                            style: GoogleFonts.inter(fontSize: 13, color: cs.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Consumer<AuthViewModel>(
            builder: (context, vm, _) {
              if (vm.isLoading) {
                return const SizedBox(
                  height: 48,
                  child: Center(child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )),
                );
              }
              return SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _handleSignIn,
                  child: Text('Entrar',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('¿No tienes cuenta?',
                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterView()),
                ),
                child: Text('Regístrate',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
              ),
            ],
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactView()),
              ),
              icon: Icon(Icons.mail_outline_rounded, size: 15, color: cs.onSurfaceVariant),
              label: Text('Contacto',
                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativePattern extends StatelessWidget {
  final Color color;
  const _DecorativePattern({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PatternPainter(color: color));
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;
  const _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.07)..style = PaintingStyle.fill;
    final stroke = Paint()..color = color.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), size.width * 0.3, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.8), size.width * 0.4, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.1), size.width * 0.15, stroke);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.85), size.width * 0.18, stroke);
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.color != color;
}
