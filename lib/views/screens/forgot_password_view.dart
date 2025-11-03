import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/validators.dart';
import 'reset_password_view.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
      _message = null;
    });

    final authViewModel = context.read<AuthViewModel>();
    final result = await authViewModel.requestPasswordReset(
      _emailController.text.trim(),
    );

    setState(() {
      _isSending = false;
    });

    if (result && mounted) {
      setState(() {
        _isError = false;
        _message = '✅ Código enviado. Revisa tu email.';
      });

      // Navegar a la pantalla de restablecimiento después de 1 segundo
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResetPasswordView(email: _emailController.text.trim()),
            ),
          );
        }
      });
    } else if (mounted) {
      setState(() {
        _isError = true;
        _message =
            authViewModel.errorMessage ??
            '❌ Error al enviar el código. Verifica el email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ingresa tu email y te enviaremos un código para restablecer tu contraseña',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_isSending,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendResetEmail(),
                validator: Validators.validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isError ? Colors.red : Colors.green,
                      fontSize: 14,
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
                  onPressed: _sendResetEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar código'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
