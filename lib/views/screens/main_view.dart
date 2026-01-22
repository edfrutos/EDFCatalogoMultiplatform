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

    // Detectar si es móvil (ancho < 600px) o tablet/desktop
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: isMobile ? _buildDrawer(context, authViewModel, isAdmin) : null,
      body: Row(
        children: [
          // Sidebar solo en desktop/tablet
          if (!isMobile) ...[
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
          ],
          // Content
          Expanded(child: _buildDetailView()),
        ],
      ),
      // AppBar para móvil con botón de menú
      appBar: isMobile
          ? AppBar(
              title: Text(_getAppBarTitle()),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => authViewModel.signOut(),
                  tooltip: 'Cerrar sesión',
                ),
              ],
            )
          : null,
    );
  }

  String _getAppBarTitle() {
    switch (_selectedItem) {
      case NavigationItem.catalogs:
        return 'Catálogos';
      case NavigationItem.profile:
        return 'Perfil';
      case NavigationItem.admin:
        return 'Administración';
      case null:
        return 'App';
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthViewModel authViewModel,
    bool isAdmin,
  ) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Botones de navegación
            _buildDrawerItem(
              icon: Icons.folder,
              label: 'Catálogos',
              isSelected: _selectedItem == NavigationItem.catalogs,
              onTap: () {
                Navigator.of(context).pop(); // Cerrar drawer
                setState(() {
                  _selectedItem = NavigationItem.catalogs;
                });
              },
            ),
            _buildDrawerItem(
              icon: Icons.person,
              label: 'Perfil',
              isSelected: _selectedItem == NavigationItem.profile,
              onTap: () {
                Navigator.of(context).pop(); // Cerrar drawer
                setState(() {
                  _selectedItem = NavigationItem.profile;
                });
              },
            ),
            if (isAdmin)
              _buildDrawerItem(
                icon: Icons.settings,
                label: 'Administración',
                isSelected: _selectedItem == NavigationItem.admin,
                onTap: () {
                  Navigator.of(context).pop(); // Cerrar drawer
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
                Navigator.of(context).pop(); // Cerrar drawer
                authViewModel.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
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
