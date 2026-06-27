import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/mongo_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ContactView extends StatefulWidget {
  const ContactView({super.key});

  @override
  State<ContactView> createState() => _ContactViewState();
}

class _ContactViewState extends State<ContactView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        final displayName =
            (user.fullName?.isNotEmpty == true ? user.fullName! : user.name)
                .trim();
        _nameController.text = displayName;
        _emailController.text = user.email.trim();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final ok = await MongoService.shared.saveContactMessage(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        setState(() {
          _sending = false;
          _sent = true;
        });
        _subjectController.clear();
        _messageController.clear();
      } else {
        setState(() => _sending = false);
        _showError('No se pudo enviar el mensaje. Inténtalo de nuevo.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError('Error al enviar: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reset() => setState(() => _sent = false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacto',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Envíanos un mensaje y te responderemos lo antes posible.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sent ? _buildSuccess(cs) : _buildForm(cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(
                controller: _nameController,
                label: 'Nombre',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El email es obligatorio';
                  if (!v.contains('@')) return 'Email no válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _subjectController,
                label: 'Asunto',
                icon: Icons.subject_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El asunto es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _messageController,
                label: 'Mensaje',
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 6,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El mensaje es obligatorio';
                  if (v.trim().length < 10) return 'El mensaje es demasiado corto';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _sending ? 'Enviando…' : 'Enviar mensaje',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _buildSuccess(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: cs.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '¡Mensaje enviado!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hemos recibido tu mensaje y te responderemos en breve.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Enviar otro mensaje'),
            ),
          ],
        ),
      ),
    );
  }
}
