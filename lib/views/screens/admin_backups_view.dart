import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart' as file_picker;
import '../../viewmodels/backup_viewmodel.dart';
import '../../models/backup_info.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    // Escuchar cambios de pestaña para cargar backups automáticamente
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Cargar backups según la pestaña inicial (índice 0 = Catálogos)
      final viewModel = context.read<BackupViewModel>();
      print(
        '🎯 Inicializando vista de backups - pestaña inicial: ${_tabController.index}',
      );
      _loadBackupsForTab(_tabController.index, viewModel);
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final viewModel = context.read<BackupViewModel>();
      print(
        '🔄 Cambio de pestaña detectado - nueva pestaña: ${_tabController.index}',
      );
      _loadBackupsForTab(_tabController.index, viewModel);
    }
  }

  void _loadBackupsForTab(int tabIndex, BackupViewModel viewModel) {
    // Cargar backups según la pestaña seleccionada
    switch (tabIndex) {
      case 0: // Backups de Catálogos
        print('📂 Cargando backups de catálogos desde Google Drive');
        viewModel.loadBackups(
          type: BackupType.catalogs,
          loadProjectBackups: false,
        );
        break;
      case 1: // Backups de Usuarios
        print('👥 Cargando backups de usuarios desde Google Drive');
        viewModel.loadBackups(
          type: BackupType.users,
          loadProjectBackups: false,
        );
        break;
      case 2: // Backups del Proyecto
        print('📁 Cargando backups del proyecto desde Google Drive');
        viewModel.loadBackups(type: BackupType.project);
        break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      const Icon(Icons.backup, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Gestión de Backups',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Botones de acción - scroll horizontal si es necesario
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
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
                        const SizedBox(width: 8),
                        // Botón crear backup del proyecto
                        ElevatedButton.icon(
                          onPressed: viewModel.isLoading
                              ? null
                              : () => _createProjectBackup(context, viewModel),
                          icon: const Icon(Icons.folder_copy, size: 18),
                          label: const Text('Proyecto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                Tab(
                  icon: Icon(Icons.folder_copy),
                  text: 'Backups del Proyecto',
                ),
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
                  _buildProjectBackupsList(context, viewModel),
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
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Tamaño: ${backup.formattedSize}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Fecha: ${backup.formattedDate}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteBackup(context, viewModel, backup, type);
                  } else if (value == 'download') {
                    _downloadBackup(context, viewModel, backup, type);
                  } else if (value == 'restore') {
                    _restoreBackup(context, viewModel, backup, type);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.restore, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Restaurar', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
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

  Future<void> _restoreBackup(
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

    // Mostrar confirmación con advertencia
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Restaurar backup de ${type == BackupType.catalogs ? 'catálogos' : 'usuarios'}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas restaurar el backup "${backup.fileName}"?',
            ),
            const SizedBox(height: 16),
            if (type == BackupType.catalogs)
              const Text(
                '⚠️ Se crearán nuevos catálogos en la base de datos. Los catálogos existentes no serán modificados.',
                style: TextStyle(color: Colors.orange),
              )
            else
              const Text(
                '⚠️ Se crearán nuevos usuarios en la base de datos. Los usuarios existentes (por email) no serán restaurados.',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
              'Restaurando backup de ${type == BackupType.catalogs ? 'catálogos' : 'usuarios'}...',
            ),
          ],
        ),
      ),
    );

    try {
      if (type == BackupType.catalogs) {
        await viewModel.restoreCatalogBackup(backup.driveFileId!);
      } else {
        await viewModel.restoreUserBackup(backup.driveFileId!);
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        // Mostrar resultado
        if (viewModel.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.successMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // Recargar lista de backups
        await viewModel.loadBackups(type: type, loadProjectBackups: false);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        // Si es un proyecto (ZIP), guardarlo en lugar de mostrar detalles
        if (type == BackupType.project && data['bytes'] != null) {
          final zipBytes = data['bytes'] as List<int>;
          final result = await file_picker.FilePicker.platform.saveFile(
            fileName: backup.fileName,
            type: file_picker.FileType.custom,
            allowedExtensions: ['zip'],
          );

          if (result != null) {
            final file = File(result);
            await file.writeAsBytes(zipBytes);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Backup descargado: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }

        // Para catálogos/usuarios, mostrar detalles del backup
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
                    'Tipo: ${type == BackupType.catalogs
                        ? 'Catálogos'
                        : type == BackupType.users
                        ? 'Usuarios'
                        : 'Proyecto'}',
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

  /// Crear backup del proyecto
  Future<void> _createProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
  ) async {
    // Mostrar confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear backup del proyecto'),
        content: const Text(
          '¿Estás seguro de que deseas crear un backup completo del proyecto? '
          'Esto puede tardar varios minutos dependiendo del tamaño del proyecto.',
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
              const Text('Creando backup del proyecto...'),
              const SizedBox(height: 8),
              const Text(
                'Esto puede tardar varios minutos',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Intentar crear backup sin directorio específico primero
      // uploadToGoogleDrive está en true por defecto, pero lo especificamos explícitamente
      try {
        await viewModel.createProjectBackup(uploadToGoogleDrive: true);
      } catch (e) {
        // El error ya está guardado en viewModel.errorMessage
        print('Error capturado en _createProjectBackup: $e');
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        // Debug: verificar estado del ViewModel
        print('🔍 UI - Después de crear backup:');
        print('   isLoading: ${viewModel.isLoading}');
        print('   successMessage: ${viewModel.successMessage}');
        print('   errorMessage: ${viewModel.errorMessage}');

        // Esperar un momento para asegurar que los listeners se hayan actualizado
        await Future.delayed(const Duration(milliseconds: 200));

        // Verificar si hay mensaje de éxito o error
        if (viewModel.successMessage != null) {
          print('✅ UI - Mostrando mensaje de éxito');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.successMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          // Recargar backups
          await viewModel.loadBackups(type: BackupType.project);
        } else if (viewModel.errorMessage != null) {
          print('❌ UI - Hay error: ${viewModel.errorMessage}');
          // Si hay error relacionado con permisos, pedir al usuario que seleccione directorio del proyecto
          final errorMsg = viewModel.errorMessage!.toLowerCase();
          final isPermissionError =
              errorMsg.contains('permisos') ||
              errorMsg.contains('permission') ||
              errorMsg.contains('operation not permitted') ||
              errorMsg.contains('pathaccessexception') ||
              errorMsg.contains('no se puede acceder');

          print('🔍 UI - ¿Es error de permisos? $isPermissionError');

          if (isPermissionError && context.mounted) {
            print('🔐 UI - Mostrando diálogo de permisos');

            // Esperar un frame adicional para asegurar que la UI esté lista
            await Future.delayed(const Duration(milliseconds: 100));

            // Verificar que el contexto siga siendo válido
            if (!context.mounted) {
              print('⚠️ UI - Contexto no válido, no se puede mostrar diálogo');
              return;
            }

            // Usar rootNavigator para que el diálogo persista incluso si cambia la pestaña
            // Preguntar si quiere seleccionar el directorio del proyecto
            // Asegurar que el diálogo se muestre de forma prominente
            final selectDir = await showDialog<bool>(
              context: context,
              barrierDismissible: false, // No permitir cerrar tocando fuera
              useRootNavigator:
                  true, // Usar el Navigator root para que persista
              barrierColor:
                  Colors.black54, // Fondo más oscuro para destacar el diálogo
              builder: (dialogContext) => PopScope(
                canPop: false, // Prevenir cierre con botón de retroceso
                child: AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Permisos insuficientes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'No se puede acceder al directorio del proyecto por falta de permisos.\n\n'
                    'Por favor, selecciona el directorio del proyecto para otorgar permisos de lectura.\n\n'
                    'El backup se subirá directamente a Google Drive.',
                    style: TextStyle(fontSize: 16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(false);
                      },
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text('Seleccionar Directorio'),
                      ),
                    ),
                  ],
                ),
              ),
            );

            print('🔐 UI - Diálogo cerrado con resultado: $selectDir');

            if (selectDir == true) {
              // Pedir al usuario que seleccione el directorio del proyecto
              // (para obtener permisos de lectura)
              final selectedProjectDir = await file_picker.FilePicker.platform
                  .getDirectoryPath(
                    dialogTitle:
                        'Selecciona el directorio del PROYECTO para hacer backup',
                  );

              if (selectedProjectDir != null && context.mounted) {
                // Mostrar loading nuevamente
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Creando backup del proyecto...'),
                        const SizedBox(height: 8),
                        const Text(
                          'Esto puede tardar varios minutos',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );

                // Crear backup usando el directorio del proyecto seleccionado
                // uploadToGoogleDrive está en true por defecto, se subirá directamente a Google Drive
                try {
                  await viewModel.createProjectBackup(
                    projectPath: selectedProjectDir,
                    uploadToGoogleDrive: true,
                  );
                } catch (e) {
                  // El error ya está guardado en viewModel.errorMessage
                  print(
                    'Error capturado al crear backup con directorio seleccionado: $e',
                  );
                }

                if (context.mounted) {
                  Navigator.of(context).pop(); // Cerrar loading

                  // Mostrar mensaje de éxito o error (igual que para catálogos/usuarios)
                  if (viewModel.successMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(viewModel.successMessage!),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    // Recargar backups
                    await viewModel.loadBackups(type: BackupType.project);
                  } else if (viewModel.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(viewModel.errorMessage!),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              } else if (selectedProjectDir == null) {
                // Usuario canceló la selección de directorio, limpiar mensaje de error
                print('⚠️ UI - Usuario canceló la selección de directorio');
                viewModel.clearMessages();
              }
            } else {
              // Usuario canceló el diálogo de permisos, limpiar mensaje de error
              print('⚠️ UI - Usuario canceló el diálogo de permisos');
              viewModel.clearMessages();
            }
          } else {
            // Error no relacionado con permisos, mostrar mensaje de error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(viewModel.errorMessage!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }

  /// Construir lista de backups del proyecto
  Widget _buildProjectBackupsList(
    BuildContext context,
    BackupViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.projectBackups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.projectBackups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_copy_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay backups del proyecto',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.loadBackups(type: BackupType.project),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: viewModel.projectBackups.length,
        itemBuilder: (context, index) {
          final backup = viewModel.projectBackups[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.folder_copy, color: Colors.white),
              ),
              title: Text(
                backup.fileName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Tamaño: ${backup.formattedSize}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Fecha: ${backup.formattedDate}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (backup.isGoogleDrive)
                    const Text(
                      '📍 Google Drive',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'restore') {
                    _restoreProjectBackup(context, viewModel, backup);
                  } else if (value == 'download') {
                    _viewProjectBackupDetails(context, viewModel, backup);
                  } else if (value == 'delete') {
                    _deleteProjectBackup(context, viewModel, backup);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.restore, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Restaurar', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
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

  /// Ver detalles del backup del proyecto
  Future<void> _viewProjectBackupDetails(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
  ) async {
    // Mostrar detalles del backup sin descargar
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
              const Text('Tipo: Proyecto'),
              if (backup.isGoogleDrive)
                const Text(
                  '📍 Google Drive',
                  style: TextStyle(color: Colors.blue),
                ),
              const SizedBox(height: 16),
              const Text(
                'Para restaurar este backup, descárgalo y extrae el contenido en la ubicación deseada.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadProjectBackup(context, viewModel, backup);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  /// Restaurar backup del proyecto (descargar y mostrar instrucciones)
  Future<void> _restoreProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
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
        title: const Text('Restaurar backup del proyecto'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ Restaurar un backup del proyecto requiere descargarlo y extraerlo manualmente.',
            ),
            SizedBox(height: 16),
            Text(
              'Se descargará el archivo ZIP del backup. Después de descargarlo:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Extrae el contenido del ZIP'),
            Text('2. Copia los archivos a la ubicación deseada'),
            Text('3. Reemplaza los archivos existentes si es necesario'),
            SizedBox(height: 16),
            Text(
              '¿Deseas descargar el backup ahora?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Descargar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadProjectBackup(context, viewModel, backup);
    }
  }

  /// Descargar backup del proyecto
  Future<void> _downloadProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
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
            const Text('Descargando backup del proyecto...'),
          ],
        ),
      ),
    );

    try {
      final data = await viewModel.downloadBackup(
        backup.driveFileId!,
        BackupType.project,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        if (data != null && data['bytes'] != null) {
          // Guardar el ZIP usando file_picker
          final zipBytes = data['bytes'] as List<int>;
          final result = await file_picker.FilePicker.platform.saveFile(
            fileName: backup.fileName,
            type: file_picker.FileType.custom,
            allowedExtensions: ['zip'],
          );

          if (result != null) {
            final file = File(result);
            await file.writeAsBytes(zipBytes);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Backup descargado: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se pudo descargar el backup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Eliminar backup del proyecto
  Future<void> _deleteProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
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
        title: const Text('Eliminar backup del proyecto'),
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
      await viewModel.deleteBackup(backup.driveFileId!, BackupType.project);
    }
  }
}
