import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user.dart';
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

  List<User> _getFilteredUsers(List<User> users) {
    if (_searchText.isEmpty) {
      return users;
    }
    return users.where((user) {
      return user.email.toLowerCase().contains(_searchText.toLowerCase()) ||
          user.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          user.username.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (context, viewModel, _) {
        final filteredUsers = _getFilteredUsers(viewModel.users);

        final isMobile = MediaQuery.of(context).size.width < 600;

        return Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera fila: Título y botón refresh
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestión de Usuarios',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: ${viewModel.users.length} usuarios',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        color: Colors.blue,
                        onPressed: viewModel.isLoading
                            ? null
                            : () {
                                viewModel.loadUsers();
                              },
                      ),
                    ],
                  ),
                  // Segunda fila: Botón Crear Usuario (en móvil, solo icono)
                  const SizedBox(height: 8),
                  isMobile
                      ? IconButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateUserDialog(),
                                  );
                                },
                          icon: const Icon(Icons.person_add),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                          tooltip: 'Crear Usuario',
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: viewModel.isLoading
                                ? null
                                : () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          const CreateUserDialog(),
                                    );
                                  },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Crear Usuario'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por email, nombre o usuario',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Messages
            if (viewModel.errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.red,
                      onPressed: () {
                        viewModel.clearMessages();
                      },
                    ),
                  ],
                ),
              ),
            if (viewModel.successMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.green,
                      onPressed: () {
                        viewModel.clearMessages();
                      },
                    ),
                  ],
                ),
              ),
            // User List
            Expanded(
              child: viewModel.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Cargando usuarios...'),
                        ],
                      ),
                    )
                  : filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchText.isEmpty
                                ? Icons.person_off
                                : Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchText.isEmpty
                                ? 'No hay usuarios'
                                : 'No se encontraron resultados',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => viewModel.loadUsers(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _UserListItem(
                            user: user,
                            onSelect: () {
                              viewModel.selectUser(user);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminUserDetailView(user: user),
                                ),
                              );
                            },
                            onToggleRole: () {
                              viewModel.updateUserRole(
                                user,
                                isAdmin: !user.isAdmin,
                              );
                            },
                            onToggleActive: () {
                              viewModel.updateUserActiveStatus(
                                user,
                                isActive: !(user.isActive ?? true),
                              );
                            },
                            onDelete: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Eliminar Usuario'),
                                  content: Text(
                                    '¿Deseas eliminar a ${user.email}? Esta acción no se puede deshacer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        viewModel.deleteUser(user);
                                        Navigator.of(context).pop();
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                            },
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

class _UserListItem extends StatelessWidget {
  final User user;
  final VoidCallback onSelect;
  final VoidCallback onToggleRole;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _UserListItem({
    required this.user,
    required this.onSelect,
    required this.onToggleRole,
    required this.onToggleActive,
    required this.onDelete,
  });

  Widget _buildAvatar(BuildContext context) {
    final initials = Text(
      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
      style: TextStyle(
        color: Colors.blue.shade700,
        fontWeight: FontWeight.bold,
      ),
    );

    if (user.profileImageUrl == null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade100,
        child: initials,
      );
    }

    return S3PresignedBuilder(
      rawUrl: user.profileImageUrl!,
      loadingWidget: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade100,
        child: initials,
      ),
      errorWidget: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade100,
        child: initials,
      ),
      builder: (context, signedUrl) => CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: CachedNetworkImageProvider(signedUrl),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar con foto de perfil si existe
              _buildAvatar(context),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  size: 12,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle_notifications,
                                  size: 12,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Inactivo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Actions Menu
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 8),
                        Text('Ver Detalles'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(
                          user.isAdmin
                              ? Icons.person
                              : Icons.admin_panel_settings,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(user.isAdmin ? 'Hacer Usuario' : 'Hacer Admin'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.circle_notifications
                              : Icons.check_circle,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Desactivar' : 'Activar'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onSelect();
                      break;
                    case 'role':
                      onToggleRole();
                      break;
                    case 'active':
                      onToggleActive();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
