import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_user_detail_view.dart';
import 'widgets/create_user_dialog.dart';
import 'widgets/s3_presigned_widget.dart';

class AdminUsersListView extends StatefulWidget {
  const AdminUsersListView({super.key});

  @override
  State<AdminUsersListView> createState() => _AdminUsersListViewState();
}

class _AdminUsersListViewState extends State<AdminUsersListView> {
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> _getFiltered(List<User> users) {
    if (_searchText.isEmpty) return users;
    final q = _searchText.toLowerCase();
    return users.where((u) =>
        u.email.toLowerCase().contains(q) ||
        u.name.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q)).toList();
  }

  void _showCreateUser(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const CreateUserDialog(),
      );

  void _showDeleteDialog(BuildContext context, AdminViewModel vm, User user) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.delete_rounded, color: cs.error, size: 28),
        title: Text('Eliminar usuario',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          '¿Deseas eliminar a ${user.email}? Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              vm.deleteUser(user);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<AdminViewModel>(
      builder: (context, vm, _) {
        final filtered = _getFiltered(vm.users);

        return Column(
          children: [
            // ── Toolbar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuarios',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${vm.users.length} registrados',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: cs.primary,
                    onPressed: vm.isLoading ? null : vm.loadUsers,
                    tooltip: 'Recargar',
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () => _showCreateUser(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Crear'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

            // ── Búsqueda ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por email, nombre o usuario...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchText = v),
              ),
            ),

            const SizedBox(height: 8),

            // ── Mensajes ─────────────────────────────────────────────
            if (vm.errorMessage != null)
              _Banner(
                  message: vm.errorMessage!,
                  isError: true,
                  cs: cs,
                  onClose: vm.clearMessages),
            if (vm.successMessage != null)
              _Banner(
                  message: vm.successMessage!,
                  isError: false,
                  cs: cs,
                  onClose: vm.clearMessages),

            // ── Lista ────────────────────────────────────────────────
            Expanded(
              child: vm.isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: cs.primary),
                          const SizedBox(height: 14),
                          Text('Cargando usuarios...',
                              style: GoogleFonts.inter(
                                  color: cs.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? _EmptyState(
                          isSearch: _searchText.isNotEmpty, cs: cs)
                      : RefreshIndicator(
                          onRefresh: vm.loadUsers,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final user = filtered[i];
                              return _UserCard(
                                user: user,
                                cs: cs,
                                onSelect: () {
                                  vm.selectUser(user);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminUserDetailView(user: user),
                                    ),
                                  );
                                },
                                onToggleRole: () =>
                                    vm.updateUserRole(user,
                                        isAdmin: !user.isAdmin),
                                onToggleActive: () =>
                                    vm.updateUserActiveStatus(user,
                                        isActive: !(user.isActive ?? true)),
                                onDelete: () =>
                                    _showDeleteDialog(context, vm, user),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Banner de estado ──────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  final ColorScheme cs;
  final VoidCallback onClose;

  const _Banner(
      {required this.message,
      required this.isError,
      required this.cs,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? cs.errorContainer : cs.tertiaryContainer;
    final fg = isError ? cs.onErrorContainer : cs.onTertiaryContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      child: Row(
        children: [
          Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(fontSize: 13, color: fg))),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: fg),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isSearch;
  final ColorScheme cs;
  const _EmptyState({required this.isSearch, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
                size: 36, color: cs.onSurface.withOpacity(0.35)),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin resultados' : 'Sin usuarios',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Prueba con otro término de búsqueda'
                : 'No hay usuarios registrados todavía',
            style: GoogleFonts.inter(
                fontSize: 13, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de usuario ────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final User user;
  final ColorScheme cs;
  final VoidCallback onSelect;
  final VoidCallback onToggleRole;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.cs,
    required this.onSelect,
    required this.onToggleRole,
    required this.onToggleActive,
    required this.onDelete,
  });

  Widget _buildAvatar() {
    final initial = Text(
      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
      style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
    );
    final fallback = CircleAvatar(
      radius: 22,
      backgroundColor: cs.primaryContainer,
      child: initial,
    );

    if (user.profileImageUrl == null) return fallback;

    return S3PresignedBuilder(
      rawUrl: user.profileImageUrl!,
      loadingWidget: fallback,
      errorWidget: fallback,
      builder: (context, url) => CircleAvatar(
        radius: 22,
        backgroundColor: cs.primaryContainer,
        backgroundImage: CachedNetworkImageProvider(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = user.isActive ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (user.isAdmin)
                          _StatusChip(
                            label: 'Admin',
                            icon: Icons.admin_panel_settings_rounded,
                            bg: cs.tertiaryContainer,
                            fg: cs.onTertiaryContainer,
                          ),
                        if (!isActive)
                          _StatusChip(
                            label: 'Inactivo',
                            icon: Icons.block_rounded,
                            bg: cs.errorContainer,
                            fg: cs.onErrorContainer,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.55)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user.username}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.primary.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: cs.onSurface.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                onSelected: (v) {
                  switch (v) {
                    case 'view': onSelect();
                    case 'role': onToggleRole();
                    case 'active': onToggleActive();
                    case 'delete': onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'view',
                    child: _MenuItem(
                        icon: Icons.person_rounded,
                        label: 'Ver detalles',
                        color: cs.primary),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'role',
                    child: _MenuItem(
                      icon: user.isAdmin
                          ? Icons.person_rounded
                          : Icons.admin_panel_settings_rounded,
                      label: user.isAdmin ? 'Quitar admin' : 'Hacer admin',
                      color: cs.tertiary,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'active',
                    child: _MenuItem(
                      icon: isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      label: isActive ? 'Desactivar' : 'Activar',
                      color: isActive ? cs.error : Colors.green,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: _MenuItem(
                        icon: Icons.delete_rounded,
                        label: 'Eliminar',
                        color: cs.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _StatusChip(
      {required this.label,
      required this.icon,
      required this.bg,
      required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.inter(fontSize: 14, color: color)),
      ],
    );
  }
}
