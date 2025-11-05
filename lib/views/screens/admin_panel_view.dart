import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'admin_users_list_view.dart';
import 'admin_catalogs_list_view.dart';
import 'admin_statistics_view.dart';
import 'admin_backups_view.dart';

enum AdminTab { users, catalogs, statistics, backups }

class AdminPanelView extends StatefulWidget {
  final User currentUser;

  const AdminPanelView({super.key, required this.currentUser});

  @override
  State<AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<AdminPanelView> {
  AdminTab _selectedTab = AdminTab.users;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel de Administración',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.currentUser.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Navigation - Scroll horizontal si es necesario
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: isMobile
                  ? Row(
                      children: [
                        _buildMobileTab(
                          AdminTab.users,
                          Icons.people,
                          'Usuarios',
                        ),
                        const SizedBox(width: 8),
                        _buildMobileTab(
                          AdminTab.catalogs,
                          Icons.library_books,
                          'Catálogos',
                        ),
                        const SizedBox(width: 8),
                        _buildMobileTab(
                          AdminTab.statistics,
                          Icons.bar_chart,
                          'Estadísticas',
                        ),
                        const SizedBox(width: 8),
                        _buildMobileTab(
                          AdminTab.backups,
                          Icons.backup,
                          'Backups',
                        ),
                      ],
                    )
                  : SegmentedButton<AdminTab>(
                      segments: const [
                        ButtonSegment(
                          value: AdminTab.users,
                          label: Text('Usuarios'),
                          icon: Icon(Icons.people),
                        ),
                        ButtonSegment(
                          value: AdminTab.catalogs,
                          label: Text('Catálogos'),
                          icon: Icon(Icons.library_books),
                        ),
                        ButtonSegment(
                          value: AdminTab.statistics,
                          label: Text('Estadísticas'),
                          icon: Icon(Icons.bar_chart),
                        ),
                        ButtonSegment(
                          value: AdminTab.backups,
                          label: Text('Backups'),
                          icon: Icon(Icons.backup),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (Set<AdminTab> newSelection) {
                        setState(() {
                          _selectedTab = newSelection.first;
                        });
                      },
                    ),
            ),
          ),
          // Content
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildMobileTab(AdminTab tab, IconData icon, String label) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case AdminTab.users:
        return const AdminUsersListView();
      case AdminTab.catalogs:
        return const AdminCatalogsListView();
      case AdminTab.statistics:
        return const AdminStatisticsView();
      case AdminTab.backups:
        return const AdminBackupsView();
    }
  }
}
