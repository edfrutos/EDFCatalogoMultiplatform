import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/backup_viewmodel.dart';
import 'admin_panel_view.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        final currentUser = authViewModel.currentUser;

        if (currentUser == null) {
          return const Center(
            child: Text('Error: No se pudo cargar el usuario'),
          );
        }

        if (!currentUser.isAdmin) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Acceso Denegado',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'No tienes permisos para acceder al panel de administración. Solo los administradores pueden acceder a esta sección.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AdminViewModel()),
            ChangeNotifierProvider(create: (_) => BackupViewModel()),
          ],
          child: AdminPanelView(currentUser: currentUser),
        );
      },
    );
  }
}
