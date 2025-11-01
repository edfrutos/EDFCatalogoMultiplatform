import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'screens/login_view.dart';
import 'screens/main_view.dart';

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  @override
  void initState() {
    super.initState();
    // Intentar restaurar la sesión al iniciar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final authViewModel = context.read<AuthViewModel>();
          authViewModel.restoreSession().catchError((error) {
            // Ignorar errores al restaurar sesión, simplemente mostrar login
            print('⚠️ Error al restaurar sesión: $error');
          });
        } catch (e) {
          print('⚠️ Error al acceder a AuthViewModel: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        if (authViewModel.isAuthenticated) {
          return const MainView();
        } else {
          return const LoginView();
        }
      },
    );
  }
}

