import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/validators.dart';

class ResetPasswordView extends StatefulWidget {
  final String email;

  const ResetPasswordView({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _resetCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isResetting = false;
  String? _message;
  bool _isError = false;

  bool get _passwordsMatch =>
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isFormValid =>
      _resetCodeController.text.length == 6 &&
      _newPasswordController.text.length >= 6 &&
      _passwordsMatch;

  @override
  void dispose() {
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isResetting = true;
      _message = null;
    });

    final authViewModel = context.read<AuthViewModel>();
    final result = await authViewModel.resetPassword(
      email: widget.email,
      token: _resetCodeController.text,
      newPassword: _newPasswordController.text,
    );

    setState(() {
      _isResetting = false;
    });

    if (result && mounted) {
      setState(() {
        _isError = false;
        _message = '✅ Contraseña restablecida correctamente';
      });

      // Cerrar modal después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(); // Cerrar ResetPasswordView
          Navigator.of(context).pop(); // Cerrar ForgotPasswordView
        }
      });
    } else if (mounted) {
      setState(() {
        _isError = true;
        _message = authViewModel.errorMessage ?? '❌ Error al restablecer la contraseña';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Se ha enviado un código de 6 dígitos a:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Código de verificación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _resetCodeController,
                decoration: const InputDecoration(
                  labelText: 'Ingresa el código de 6 dígitos',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                enabled: !_isResetting,
                keyboardType: TextInputType.number,
                maxLength: 6,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                onChanged: (value) {
                  // Limitar a solo números
                  final filtered = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (filtered != value) {
                    _resetCodeController.value = TextEditingValue(
                      text: filtered,
                      selection: TextSelection.collapsed(offset: filtered.length),
                    );
                  }
                },
                validator: Validators.validateResetCode,
              ),
              const SizedBox(height: 24),
              const Text(
                'Nueva contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'Mínimo 6 caracteres',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                enabled: !_isResetting,
                obscureText: _obscureNewPassword,
                validator: (value) => Validators.validatePassword(value, minLength: 6),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                enabled: !_isResetting,
                obscureText: _obscureConfirmPassword,
                validator: (value) => Validators.validatePasswordMatch(
                  value,
                  _newPasswordController.text,
                ),
              ),
              if (!_newPasswordController.text.isEmpty &&
                  !_confirmPasswordController.text.isEmpty &&
                  !_passwordsMatch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '⚠️ Las contraseñas no coinciden',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
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
              if (_isResetting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Restableciendo contraseña...'),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _isFormValid ? _resetPassword : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Restablecer contraseña'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

