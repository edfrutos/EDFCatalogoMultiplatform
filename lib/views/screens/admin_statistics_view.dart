import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/catalog.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../services/mongo_service.dart';

class AdminStatisticsView extends StatefulWidget {
  const AdminStatisticsView({super.key});

  @override
  State<AdminStatisticsView> createState() => _AdminStatisticsViewState();
}

class _AdminStatisticsViewState extends State<AdminStatisticsView> {
  List<Catalog> _catalogs = [];
  bool _isLoading = false;
  int _totalRows = 0;

  int get _totalUsers => context.watch<AdminViewModel>().users.length;
  int get _activeUsers =>
      context.watch<AdminViewModel>().users.where((u) => u.isActive ?? true).length;
  int get _adminUsers =>
      context.watch<AdminViewModel>().users.where((u) => u.isAdmin).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final adminVm = context.read<AdminViewModel>();
      if (adminVm.users.isEmpty) await adminVm.loadUsers();
      if (!mounted) return;

      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        _catalogs = await MongoService().getCatalogs(
          user.id, isAdmin: user.isAdmin, userEmail: user.email,
        );
        _totalRows =
            _catalogs.fold(0, (s, c) => s + c.rows.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Text('Estadísticas',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: cs.primary,
                onPressed: _isLoading ? null : _load,
                tooltip: 'Recargar',
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: cs.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección Usuarios
                        _SectionTitle(title: 'Usuarios', cs: cs),
                        const SizedBox(height: 10),
                        isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Total usuarios',
                                      value: _totalUsers,
                                      icon: Icons.people_rounded,
                                      color: cs.primary,
                                      bg: cs.primaryContainer,
                                      fg: cs.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Activos',
                                      value: _activeUsers,
                                      icon: Icons.check_circle_rounded,
                                      color: Colors.green.shade700,
                                      bg: Colors.green.shade50,
                                      fg: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Inactivos',
                                      value: _totalUsers - _activeUsers,
                                      icon: Icons.block_rounded,
                                      color: cs.error,
                                      bg: cs.errorContainer,
                                      fg: cs.onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Admins',
                                      value: _adminUsers,
                                      icon: Icons.admin_panel_settings_rounded,
                                      color: cs.tertiary,
                                      bg: cs.tertiaryContainer,
                                      fg: cs.onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _StatCard(
                                    title: 'Total usuarios',
                                    value: _totalUsers,
                                    icon: Icons.people_rounded,
                                    color: cs.primary,
                                    bg: cs.primaryContainer,
                                    fg: cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          title: 'Activos',
                                          value: _activeUsers,
                                          icon: Icons.check_circle_rounded,
                                          color: Colors.green.shade700,
                                          bg: Colors.green.shade50,
                                          fg: Colors.green.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _StatCard(
                                          title: 'Inactivos',
                                          value: _totalUsers - _activeUsers,
                                          icon: Icons.block_rounded,
                                          color: cs.error,
                                          bg: cs.errorContainer,
                                          fg: cs.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _StatCard(
                                    title: 'Administradores',
                                    value: _adminUsers,
                                    icon: Icons.admin_panel_settings_rounded,
                                    color: cs.tertiary,
                                    bg: cs.tertiaryContainer,
                                    fg: cs.onTertiaryContainer,
                                  ),
                                ],
                              ),

                        const SizedBox(height: 24),

                        // Sección Catálogos
                        _SectionTitle(title: 'Catálogos', cs: cs),
                        const SizedBox(height: 10),
                        isWide
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Total catálogos',
                                      value: _catalogs.length,
                                      icon: Icons.library_books_rounded,
                                      color: cs.primary,
                                      bg: cs.primaryContainer,
                                      fg: cs.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Total filas',
                                      value: _totalRows,
                                      icon: Icons.table_rows_rounded,
                                      color: cs.secondary,
                                      bg: cs.secondaryContainer,
                                      fg: cs.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Media filas/catálogo',
                                      value: _catalogs.isEmpty
                                          ? 0
                                          : (_totalRows / _catalogs.length)
                                              .round(),
                                      icon: Icons.analytics_rounded,
                                      color: cs.tertiary,
                                      bg: cs.tertiaryContainer,
                                      fg: cs.onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _StatCard(
                                    title: 'Total catálogos',
                                    value: _catalogs.length,
                                    icon: Icons.library_books_rounded,
                                    color: cs.primary,
                                    bg: cs.primaryContainer,
                                    fg: cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          title: 'Total filas',
                                          value: _totalRows,
                                          icon: Icons.table_rows_rounded,
                                          color: cs.secondary,
                                          bg: cs.secondaryContainer,
                                          fg: cs.onSecondaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _StatCard(
                                          title: 'Media filas',
                                          value: _catalogs.isEmpty
                                              ? 0
                                              : (_totalRows / _catalogs.length)
                                                  .round(),
                                          icon: Icons.analytics_rounded,
                                          color: cs.tertiary,
                                          bg: cs.tertiaryContainer,
                                          fg: cs.onTertiaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  const _SectionTitle({required this.title, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 3, height: 18,
            decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: cs.onSurface)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color fg;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            child: Icon(icon, size: 26, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.55))),
                const SizedBox(height: 3),
                Text(
                  value.toString(),
                  style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
