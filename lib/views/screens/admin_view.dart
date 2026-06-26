import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
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
        final cs = Theme.of(context).colorScheme;

        if (currentUser == null) {
          return Center(
            child: Text(
              'Error: No se pudo cargar el usuario',
              style: GoogleFonts.inter(color: cs.error),
            ),
          );
        }

        if (!currentUser.isAdmin) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXL),
                      ),
                      child: Icon(Icons.lock_rounded,
                          size: 44, color: cs.onErrorContainer),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Acceso denegado',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        'No tienes permisos para acceder al panel de administración. Solo los administradores pueden acceder a esta sección.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: cs.onSurface.withOpacity(0.6),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
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
