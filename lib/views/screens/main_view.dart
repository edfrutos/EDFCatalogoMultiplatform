import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../utils/theme_provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/edf_logo.dart';
import 'catalogs_view.dart';
import 'contact_view.dart';
import 'profile_view.dart';
import 'admin_view.dart';

enum NavigationItem { catalogs, profile, contact, admin }

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  NavigationItem _selectedItem = NavigationItem.catalogs;

  int get _navIndex => switch (_selectedItem) {
    NavigationItem.catalogs => 0,
    NavigationItem.profile  => 1,
    NavigationItem.contact  => 2,
    NavigationItem.admin    => 3,
  };

  void _selectIndex(int index, bool isAdmin) {
    setState(() {
      _selectedItem = switch (index) {
        0 => NavigationItem.catalogs,
        1 => NavigationItem.profile,
        2 => NavigationItem.contact,
        3 when isAdmin => NavigationItem.admin,
        _ => NavigationItem.catalogs,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isAdmin = authViewModel.currentUser?.isAdmin ?? false;
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1100;
    // narrow  → BottomNavigationBar
    // tablet  → NavigationRail compacto (solo iconos)
    // desktop → NavigationRail extendido (iconos + etiquetas + logo)

    if (isNarrow) return _buildMobileLayout(context, authViewModel, isAdmin);
    if (isTablet) return _buildTabletLayout(context, authViewModel, isAdmin);
    return _buildDesktopLayout(context, authViewModel, isAdmin);
  }

  // ── Móvil: BottomNavigationBar ─────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, AuthViewModel auth, bool isAdmin) {
    return Scaffold(
      appBar: AppBar(
        title: EdfLogoHorizontal(iconSize: 28),
        actions: [
          _ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: auth.signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: isAdmin ? _navIndex : _navIndex.clamp(0, 1),
        onDestinationSelected: (i) => _selectIndex(i, isAdmin),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Catálogos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.mail_outline_rounded),
            selectedIcon: Icon(Icons.mail_rounded),
            label: 'Contacto',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin',
            ),
        ],
      ),
    );
  }

  // ── Tablet: NavigationRail compacto ────────────────────────────────────────
  Widget _buildTabletLayout(BuildContext context, AuthViewModel auth, bool isAdmin) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: false,
            selectedIndex: isAdmin ? _navIndex : _navIndex.clamp(0, 1),
            onDestinationSelected: (i) => _selectIndex(i, isAdmin),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: EdfLogoIcon(size: 36),
            ),
            trailing: Column(
              children: [
                _ThemeToggleButton(),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: auth.signOut,
                  tooltip: 'Cerrar sesión',
                ),
                const SizedBox(height: 8),
              ],
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: Text('Catálogos'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Perfil'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.mail_outline_rounded),
                selectedIcon: Icon(Icons.mail_rounded),
                label: Text('Contacto'),
              ),
              if (isAdmin)
                const NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings_rounded),
                  label: Text('Admin'),
                ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ── Desktop: NavigationRail extendido ──────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, AuthViewModel auth, bool isAdmin) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Container(
              color: cs.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: EdfLogoHorizontal(iconSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 8),
                  // Navegación
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        _SidebarNavItem(
                          icon: Icons.folder_outlined,
                          activeIcon: Icons.folder_rounded,
                          label: 'Catálogos',
                          isSelected: _selectedItem == NavigationItem.catalogs,
                          onTap: () => setState(() => _selectedItem = NavigationItem.catalogs),
                        ),
                        _SidebarNavItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Perfil',
                          isSelected: _selectedItem == NavigationItem.profile,
                          onTap: () => setState(() => _selectedItem = NavigationItem.profile),
                        ),
                        _SidebarNavItem(
                          icon: Icons.mail_outline_rounded,
                          activeIcon: Icons.mail_rounded,
                          label: 'Contacto',
                          isSelected: _selectedItem == NavigationItem.contact,
                          onTap: () => setState(() => _selectedItem = NavigationItem.contact),
                        ),
                        if (isAdmin)
                          _SidebarNavItem(
                            icon: Icons.admin_panel_settings_outlined,
                            activeIcon: Icons.admin_panel_settings_rounded,
                            label: 'Administración',
                            isSelected: _selectedItem == NavigationItem.admin,
                            onTap: () => setState(() => _selectedItem = NavigationItem.admin),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Divider(height: 1, color: cs.outlineVariant),
                  // Acciones inferiores
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      children: [
                        _SidebarActionTile(
                          icon: context.watch<ThemeProvider>().icon,
                          label: context.watch<ThemeProvider>().label,
                          onTap: () => context.read<ThemeProvider>().toggle(),
                        ),
                        _SidebarActionTile(
                          icon: Icons.logout_rounded,
                          label: 'Cerrar sesión',
                          onTap: auth.signOut,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_selectedItem) {
      NavigationItem.catalogs => const CatalogsView(),
      NavigationItem.profile  => const ProfileView(),
      NavigationItem.contact  => const ContactView(),
      NavigationItem.admin    => const AdminView(),
    };
  }
}

// ── Item de navegación para sidebar desktop ────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cs.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Acción de sidebar (sin estado seleccionado) ────────────────────────────────
class _SidebarActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botón toggle de tema ──────────────────────────────────────────────────────
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    return IconButton(
      icon: Icon(themeProv.icon),
      onPressed: () => themeProv.toggle(),
      tooltip: themeProv.label,
    );
  }
}
