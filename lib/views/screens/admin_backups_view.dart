import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/backup_viewmodel.dart';
import '../../services/google_drive_backup_service.dart';

class AdminBackupsView extends StatefulWidget {
  const AdminBackupsView({super.key});

  @override
  State<AdminBackupsView> createState() => _AdminBackupsViewState();
}

class _AdminBackupsViewState extends State<AdminBackupsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackupViewModel>().loadBackups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BackupViewModel>(
      builder: (context, viewModel, _) {
        return Column(
          children: [
            // Header con botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.backup, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      'Gestión de Backups',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón crear backup de catálogos
                  ElevatedButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _createBackup(
                            context,
                            viewModel,
                            BackupType.catalogs,
                          ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Catálogos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón crear backup de usuarios
                  ElevatedButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _createBackup(
                            context,
                            viewModel,
                            BackupType.users,
                          ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Usuarios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Mensajes de éxito/error
            if (viewModel.successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade50,
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
                      onPressed: () => viewModel.clearMessages(),
                    ),
                  ],
                ),
              ),
            if (viewModel.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
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
                      onPressed: () => viewModel.clearMessages(),
                    ),
                  ],
                ),
              ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.library_books),
                  text: 'Backups de Catálogos',
                ),
                Tab(icon: Icon(Icons.people), text: 'Backups de Usuarios'),
              ],
            ),
            // Contenido de las tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBackupsList(
                    context,
                    viewModel,
                    viewModel.catalogBackups,
                    BackupType.catalogs,
                  ),
                  _buildBackupsList(
                    context,
                    viewModel,
                    viewModel.userBackups,
                    BackupType.users,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackupsList(
    BuildContext context,
    BackupViewModel viewModel,
    List<BackupInfo> backups,
    BackupType type,
  ) {
    if (viewModel.isLoading && backups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (backups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == BackupType.catalogs
                  ? Icons.library_books_outlined
                  : Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay backups de ${type == BackupType.catalogs ? 'catálogos' : 'usuarios'}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.loadBackups(type: type),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: backups.length,
        itemBuilder: (context, index) {
          final backup = backups[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: type == BackupType.catalogs
                    ? Colors.blue
                    : Colors.green,
                child: Icon(
                  type == BackupType.catalogs
                      ? Icons.library_books
                      : Icons.people,
                  color: Colors.white,
                ),
              ),
              title: Text(
                backup.fileName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Tamaño: ${backup.formattedSize}'),
                  Text('Fecha: ${backup.formattedDate}'),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteBackup(context, viewModel, backup, type);
                  } else if (value == 'download') {
                    _downloadBackup(context, viewModel, backup, type);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Ver detalles'),
                      ],
                    ),
                  ),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupType type,
  ) async {
    // Mostrar confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Crear backup de ${type == BackupType.catalogs ? 'catálogos' : 'usuarios'}',
        ),
        content: Text(
          '¿Estás seguro de que deseas crear un backup de ${type == BackupType.catalogs ? 'todos los catálogos' : 'todos los usuarios'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crear Backup'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Creando backup de ${type == BackupType.catalogs ? 'catálogos' : 'usuarios'}...',
              ),
            ],
          ),
        ),
      );

      if (type == BackupType.catalogs) {
        await viewModel.createCatalogBackup();
      } else {
        await viewModel.createUserBackup();
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
      }
    }
  }

  Future<void> _deleteBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
    BackupType type,
  ) async {
    if (backup.driveFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del archivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar backup'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el backup "${backup.fileName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.deleteBackup(backup.driveFileId!, type);
    }
  }

  Future<void> _downloadBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
    BackupType type,
  ) async {
    if (backup.driveFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del archivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Descargando backup...'),
          ],
        ),
      ),
    );

    final data = await viewModel.downloadBackup(backup.driveFileId!, type);

    if (context.mounted) {
      Navigator.of(context).pop(); // Cerrar loading

      if (data != null) {
        // Mostrar detalles del backup
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(backup.fileName),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fecha: ${backup.formattedDate}'),
                  Text('Tamaño: ${backup.formattedSize}'),
                  Text(
                    'Tipo: ${type == BackupType.catalogs ? 'Catálogos' : 'Usuarios'}',
                  ),
                  if (data['count'] != null)
                    Text('Elementos: ${data['count']}'),
                  if (data['timestamp'] != null)
                    Text('Timestamp: ${data['timestamp']}'),
                  if (data['version'] != null)
                    Text('Versión: ${data['version']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    }
  }
}
