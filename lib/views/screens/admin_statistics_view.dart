import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../services/mongo_service.dart';
import '../../models/catalog.dart';

class AdminStatisticsView extends StatefulWidget {
  const AdminStatisticsView({super.key});

  @override
  State<AdminStatisticsView> createState() => _AdminStatisticsViewState();
}

class _AdminStatisticsViewState extends State<AdminStatisticsView> {
  List<Catalog> _catalogs = [];
  bool _isLoading = false;
  int _totalRows = 0;

  int get totalUsers {
    final viewModel = context.watch<AdminViewModel>();
    return viewModel.users.length;
  }

  int get activeUsers {
    final viewModel = context.watch<AdminViewModel>();
    return viewModel.users.where((u) => u.isActive ?? true).length;
  }

  int get adminUsers {
    final viewModel = context.watch<AdminViewModel>();
    return viewModel.users.where((u) => u.isAdmin).length;
  }

  int get totalCatalogs => _catalogs.length;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar usuarios si no están cargados
      final adminViewModel = context.read<AdminViewModel>();
      if (adminViewModel.users.isEmpty) {
        await adminViewModel.loadUsers();
      }

      // Cargar catálogos
      if (!mounted) return;
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;

      if (user != null) {
        _catalogs = await MongoService().getCatalogs(
          user.id,
          isAdmin: user.isAdmin,
          userEmail: user.email,
        );

        // Calcular total de filas
        _totalRows = _catalogs.fold(
          0,
          (sum, catalog) => sum + catalog.rows.length,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar estadísticas: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Estadísticas Generales',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.blue,
                onPressed: _isLoading ? null : _loadStatistics,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando estadísticas...'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatisticCard(
                        title: 'Total de Usuarios',
                        value: totalUsers.toString(),
                        icon: Icons.person,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _StatisticCard(
                        title: 'Usuarios Activos',
                        value: activeUsers.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _StatisticCard(
                        title: 'Usuarios Inactivos',
                        value: (totalUsers - activeUsers).toString(),
                        icon: Icons.circle_notifications,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _StatisticCard(
                        title: 'Administradores',
                        value: adminUsers.toString(),
                        icon: Icons.admin_panel_settings,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _StatisticCard(
                        title: 'Total de Catálogos',
                        value: totalCatalogs.toString(),
                        icon: Icons.library_books,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 12),
                      _StatisticCard(
                        title: 'Total de Filas',
                        value: _totalRows.toString(),
                        icon: Icons.list,
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
