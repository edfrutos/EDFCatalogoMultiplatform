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
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel de Administración',
                      style: TextStyle(
                        fontSize: 24,
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
                        Text(
                          widget.currentUser.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
          // Tab Navigation
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: SegmentedButton<AdminTab>(
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
          // Content
          Expanded(child: _buildTabContent()),
        ],
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
