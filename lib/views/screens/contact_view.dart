import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/email_service.dart';

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

  bool _isSending = false;
  String? _statusMessage;
  bool _isError = false;

  bool get _isFormValid =>
      _nameController.text.isNotEmpty &&
      _emailController.text.isNotEmpty &&
      _subjectController.text.isNotEmpty &&
      _messageController.text.isNotEmpty &&
      _emailController.text.contains('@');

  @override
  void initState() {
    super.initState();
    // Pre-rellenar con datos del usuario autenticado si están disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;
      if (user != null) {
        _nameController.text = user.name;
        _emailController.text = user.email;
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

  Future<void> _sendContactEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      await EmailService.shared.sendContactMessage(
        from: _emailController.text.trim(),
        name: _nameController.text.trim(),
        message: '${_subjectController.text.trim()}\n\n${_messageController.text.trim()}',
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _isError = false;
          _statusMessage = '✅ Mensaje enviado correctamente. ¡Gracias por contactarnos!';
        });

        // Limpiar formulario después de 2 segundos y cerrar modal
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _clearForm();
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isError = true;
          _statusMessage = '❌ Error al enviar el mensaje. Por favor, inténtalo de nuevo.';
        });
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _messageController.clear();
    _statusMessage = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !_isSending,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: !_isSending,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu email';
                  }
                  if (!value.contains('@')) {
                    return 'Por favor ingresa un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Asunto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
                enabled: !_isSending,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un asunto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Mensaje:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Escribe tu mensaje aquí...',
                ),
                enabled: !_isSending,
                maxLines: 10,
                minLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor escribe un mensaje';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isError ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
              if (_isSending)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Enviando...'),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _isFormValid ? _sendContactEmail : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar mensaje'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

