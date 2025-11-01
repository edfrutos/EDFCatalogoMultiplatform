import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'catalogs_view.dart';
import 'profile_view.dart';
import 'admin_view.dart';

enum NavigationItem { catalogs, profile, admin }

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  NavigationItem? _selectedItem = NavigationItem.catalogs;

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isAdmin = authViewModel.currentUser?.isAdmin ?? false;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar simple con ListView
          Container(
            width: 200,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Botones de navegación
                _buildNavButton(
                  icon: Icons.folder,
                  label: 'Catálogos',
                  isSelected: _selectedItem == NavigationItem.catalogs,
                  onTap: () {
                    setState(() {
                      _selectedItem = NavigationItem.catalogs;
                    });
                  },
                ),
                _buildNavButton(
                  icon: Icons.person,
                  label: 'Perfil',
                  isSelected: _selectedItem == NavigationItem.profile,
                  onTap: () {
                    setState(() {
                      _selectedItem = NavigationItem.profile;
                    });
                  },
                ),
                if (isAdmin)
                  _buildNavButton(
                    icon: Icons.settings,
                    label: 'Administración',
                    isSelected: _selectedItem == NavigationItem.admin,
                    onTap: () {
                      setState(() {
                        _selectedItem = NavigationItem.admin;
                      });
                    },
                  ),
                const Spacer(),
                const Divider(),
                // Botón cerrar sesión
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  onTap: () {
                    authViewModel.signOut();
                  },
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Content
          Expanded(child: _buildDetailView()),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    switch (_selectedItem) {
      case NavigationItem.catalogs:
        return const CatalogsView();
      case NavigationItem.profile:
        return const ProfileView();
      case NavigationItem.admin:
        return const AdminView();
      case null:
        return const Center(
          child: Text(
            'Selecciona una opción del menú',
            style: TextStyle(color: Colors.grey),
          ),
        );
    }
  }
}
