import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:file_selector/file_selector.dart' as fs;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodels/backup_viewmodel.dart';
import '../../models/backup_info.dart';
import '../../utils/logger.dart';

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

  // ignore: unused_element
  Future<String?> _pickSavePath(String suggestedName) async {
    final normalizedName =
        suggestedName.toLowerCase().endsWith('.zip') ? suggestedName : '$suggestedName.zip';

    Logger.debug(
      '[BACKUP] _pickSavePath -> sugerido="$suggestedName", normalizado="$normalizedName", '
      'Platform.isLinux=${Platform.isLinux}, kIsWeb=$kIsWeb',
    );

    // En Linux, forzamos un path de guardado automático (los diálogos nativos no aparecen)
    if (!kIsWeb && Platform.isLinux) {
      final homeDir = Platform.environment['HOME'];
      Directory? baseDir;
      if (homeDir != null && homeDir.isNotEmpty) {
        baseDir = Directory(p.join(homeDir, 'Downloads'));
        if (!baseDir.existsSync()) {
          baseDir.createSync(recursive: true);
          Logger.info('[BACKUP] (Linux) Carpeta Downloads creada: ${baseDir.path}');
        } else {
          Logger.debug('[BACKUP] (Linux) Carpeta Downloads existente: ${baseDir.path}');
        }
      } else {
        Logger.warning('[BACKUP] (Linux) HOME no definido, usaremos temporal');
      }
      baseDir ??= Directory.systemTemp;
      final path = _ensureZipExtension(p.join(baseDir.path, normalizedName));
      Logger.info('[BACKUP] (Linux) Guardando backup automáticamente en: $path');
      return path;
    }

    try {
      final result = await file_picker.FilePicker.platform.saveFile(
        fileName: normalizedName,
        type: file_picker.FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result != null && result.isNotEmpty) {
        return _ensureZipExtension(result);
      }
    } catch (e) {
      Logger.warning('[BACKUP] file_picker.saveFile no disponible: $e');
    }

    try {
      final location = await fs.getSaveLocation(
        suggestedName: normalizedName,
        acceptedTypeGroups: const [
          fs.XTypeGroup(
            label: 'Backups ZIP',
            extensions: ['zip'],
          ),
        ],
        confirmButtonText: 'Guardar',
      );
      if (location != null && location.path.isNotEmpty) {
        return _ensureZipExtension(location.path);
      }
    } catch (e) {
      Logger.warning('[BACKUP] file_selector.getSaveLocation falló: $e');
    }

    return await _resolveFallbackPath(normalizedName);
  }

  Future<String?> _resolveFallbackPath(String fileName) async {
    final normalizedName =
        fileName.toLowerCase().endsWith('.zip') ? fileName : '$fileName.zip';

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final fallbackPath = _ensureZipExtension(
          p.join(downloadsDir.path, normalizedName),
        );
        Logger.info('[BACKUP] Guardando backup en carpeta de descargas: $fallbackPath');
        return fallbackPath;
      }
    } catch (e) {
      Logger.warning('[BACKUP] No se pudo obtener la carpeta de descargas: $e');
    }

    // Último recurso: HOME del usuario
    final homeDir = Platform.environment['HOME'];
    if (homeDir != null && homeDir.isNotEmpty) {
      final fallbackPath = p.join(homeDir, 'Downloads', normalizedName);
      Logger.info('[BACKUP] Guardando backup en $fallbackPath (fallback HOME)');
      return _ensureZipExtension(fallbackPath);
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fallbackPath = _ensureZipExtension(
        p.join(tempDir.path, normalizedName),
      );
      Logger.info('[BACKUP] Guardando backup en temporal: $fallbackPath');
      return fallbackPath;
    } catch (e) {
      Logger.warning('[BACKUP] No se pudo obtener directorio temporal: $e');
    }

    return null;
  }

  String _ensureZipExtension(String path) {
    return path.toLowerCase().endsWith('.zip') ? path : '$path.zip';
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
      if (!context.mounted) return;
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
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar loading
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
    if (!context.mounted) return;

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
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar loading

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

  // Función para mostrar un diálogo con opciones para el archivo descargado
  Future<void> _showFileOptionsDialog(
    BuildContext context, 
    String filePath, 
    String fileName,
    Uint8List? fileBytes,
  ) async {
    if (!context.mounted) return;
    
    // Mostrar diálogo con opciones
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descarga completada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Archivo guardado en:\n$filePath'),
            const SizedBox(height: 16),
            if (Platform.isIOS)
              const Text(
                'Puedes acceder a este archivo desde la aplicación Archivos en tu iPhone.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'ok'),
            child: const Text('Aceptar'),
          ),
          if (fileBytes != null) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'share'),
              child: const Text('Compartir'),
            ),
          ],
        ],
      ),
    );

    if (result == 'share' && fileBytes != null && context.mounted) {
      // Usar share_plus para compartir el archivo
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes);
      
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(tempFile.path)], text: 'Compartir archivo: $fileName'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error: No se encontró el ID del archivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Para catálogos y usuarios, primero mostrar detalles sin descargar
    if (type == BackupType.catalogs || type == BackupType.users) {
      // Mostrar diálogo con detalles y opción de descargar
      final shouldDownload = await showDialog<bool>(
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
                const SizedBox(height: 16),
                const Text(
                  'Este backup contiene datos en formato JSON.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Descargar'),
            ),
          ],
        ),
      );

      // Si el usuario no quiere descargar, salir
      if (shouldDownload != true) return;
    }

    if (!context.mounted) return;
    // Mostrar diálogo de carga
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Descargando backup...'),
          ],
        ),
      ),
    );

    try {
      // Llamar al ViewModel para descargar el backup
      final data = await viewModel.downloadBackup(
        backup.driveFileId!, 
        type,
        fileName: backup.fileName,
      );

      if (!context.mounted) return;
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (data == null) {
        // Mostrar mensaje de error del ViewModel si existe
        if (viewModel.errorMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${viewModel.errorMessage}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup descargado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Si es un proyecto (ZIP), gestionar el guardado del archivo
      if (type == BackupType.project && data['bytes'] != null) {
        final zipBytes = data['bytes'] as List<int>;
        final savedPath = data['savedPath'] as String?;
        final fileName = data['fileName'] as String? ?? 'backup.zip';
        
        // Si estamos en iOS, ya se guardó el archivo en el directorio de documentos
        if (Platform.isIOS && savedPath != null) {
          await _showFileOptionsDialog(
            context, 
            savedPath, 
            fileName,
            Uint8List.fromList(zipBytes),
          );
        } else {
          // En otras plataformas, intentar el selector de archivos
          String? savedFilePath;
          try {
            final result = await file_picker.FilePicker.platform.saveFile(
              dialogTitle: 'Guardar archivo de respaldo',
              fileName: fileName,
              type: file_picker.FileType.custom,
              allowedExtensions: ['zip'],
            );
            if (result != null) {
              await File(result).writeAsBytes(zipBytes);
              savedFilePath = result;
            }
          } catch (e) {
            print('⚠️ saveFile falló: $e — usando fallback a Downloads');
          }

          // Fallback: guardar en ~/Downloads si el diálogo no funcionó
          if (savedFilePath == null) {
            try {
              final home = Platform.environment['HOME'] ?? '';
              final downloadsDir = Directory('$home/Downloads');
              if (await downloadsDir.exists()) {
                savedFilePath = '${downloadsDir.path}/$fileName';
              } else {
                final docsDir = await getApplicationDocumentsDirectory();
                savedFilePath = '${docsDir.path}/$fileName';
              }
              await File(savedFilePath!).writeAsBytes(zipBytes);
              print('✅ Backup guardado en fallback: $savedFilePath');
            } catch (e) {
              print('❌ Error guardando backup en fallback: $e');
            }
          }

          if (savedFilePath != null && context.mounted) {
            await _showFileOptionsDialog(
              context,
              savedFilePath,
              fileName,
              Uint8List.fromList(zipBytes),
            );
          }
        }
      }
      
      // Para catálogos/usuarios, el archivo ya se descargó, guardar en disco
      if ((type == BackupType.catalogs || type == BackupType.users) && data.isNotEmpty) {
        String? savedPath = data['savedPath'] as String?; // iOS ya lo guardó
        final fileName = data['fileName'] as String? ?? backup.fileName;
        final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));

        if (!context.mounted) return;

        if (Platform.isIOS && savedPath != null) {
          // iOS: ya guardado por el ViewModel
          await _showFileOptionsDialog(context, savedPath, fileName, jsonBytes);
        } else {
          // macOS / otras plataformas: guardar en ~/Downloads
          String? saveError;
          try {
            final home = Platform.environment['HOME'] ?? '';
            final downloadsDir = Directory('$home/Downloads');
            final targetDir = await downloadsDir.exists()
                ? downloadsDir
                : await getApplicationDocumentsDirectory();
            savedPath = '${targetDir.path}/$fileName';
            print('💾 Guardando backup JSON en: $savedPath');
            await File(savedPath).writeAsBytes(jsonBytes);
            print('✅ Backup JSON guardado correctamente');
          } catch (e) {
            saveError = e.toString();
            print('❌ Error guardando JSON en Downloads: $e');
            try {
              final docsDir = await getApplicationDocumentsDirectory();
              savedPath = '${docsDir.path}/$fileName';
              await File(savedPath).writeAsBytes(jsonBytes);
              print('✅ Backup JSON guardado en Documents: $savedPath');
              saveError = null;
            } catch (e2) {
              print('❌ Error guardando JSON en Documents: $e2');
              savedPath = null;
            }
          }

          if (!context.mounted) return;
          if (savedPath != null) {
            await _showFileOptionsDialog(context, savedPath, fileName, jsonBytes);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ No se pudo guardar el archivo${saveError != null ? ': $saveError' : ''}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Cerrar el diálogo de carga si hay un error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al descargar el backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      if (!context.mounted) return;
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
        if (!context.mounted) return;
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
            if (!context.mounted) return;
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
    // IMPORTANTE: guardamos el contexto externo (del widget principal) ANTES de
    // abrir el diálogo, para no pasarle el contexto del builder (que queda
    // desmontado en cuanto se hace pop del diálogo).
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Usar outerContext (no dialogContext) para que context.mounted
              // siga siendo válido después de cerrar este diálogo.
              _downloadProjectBackup(outerContext, viewModel, backup);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  /// Descargar backup del proyecto
  Future<void> _downloadProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
  ) async {
    if (backup.driveFileId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error: No se encontró el ID del archivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Mostrar diálogo de carga
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Descargando backup del proyecto...'),
          ],
        ),
      ),
    );

    try {
      // Llamar al ViewModel para descargar el backup
      final data = await viewModel.downloadBackup(
        backup.driveFileId!,
        BackupType.project,
        fileName: backup.fileName,
      );

      if (!context.mounted) return;

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (data == null) {
        if (viewModel.errorMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${viewModel.errorMessage}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Guardar el ZIP en disco
      final zipBytes = data['bytes'] as List<int>?;
      final savedPath = data['savedPath'] as String?; // iOS ya lo guardó
      final fileName = data['fileName'] as String? ?? backup.fileName;

      if (zipBytes == null || zipBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ El archivo descargado está vacío'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // iOS: archivo ya guardado por el ViewModel
      if (Platform.isIOS && savedPath != null) {
        if (context.mounted) {
          await _showFileOptionsDialog(
            context,
            savedPath,
            fileName,
            Uint8List.fromList(zipBytes),
          );
        }
        return;
      }

      // macOS / otras plataformas: guardar en ~/Downloads directamente
      String? finalPath;
      String? saveError;

      try {
        final home = Platform.environment['HOME'] ?? '';
        final downloadsDir = Directory('$home/Downloads');
        final targetDir = await downloadsDir.exists() ? downloadsDir : await getApplicationDocumentsDirectory();
        finalPath = '${targetDir.path}/$fileName';
        print('💾 Guardando backup en: $finalPath (${zipBytes.length} bytes)');
        await File(finalPath).writeAsBytes(zipBytes);
        print('✅ Backup guardado correctamente');
      } catch (e) {
        saveError = e.toString();
        print('❌ Error guardando en Downloads: $e');
        // Segundo intento: Documents de la app
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          finalPath = '${docsDir.path}/$fileName';
          await File(finalPath).writeAsBytes(zipBytes);
          print('✅ Backup guardado en Documents: $finalPath');
          saveError = null;
        } catch (e2) {
          print('❌ Error guardando en Documents: $e2');
          finalPath = null;
        }
      }

      if (!context.mounted) return;

      if (finalPath != null) {
        await _showFileOptionsDialog(
          context,
          finalPath!,
          fileName,
          Uint8List.fromList(zipBytes),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No se pudo guardar el archivo en disco${saveError != null ? ': $saveError' : ''}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al descargar el backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Restaurar backup del proyecto
  Future<void> _restoreProjectBackup(
    BuildContext context,
    BackupViewModel viewModel,
    BackupInfo backup,
  ) async {
    // Mostrar confirmación antes de restaurar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Backup del Proyecto'),
        content: const Text(
          '¿Estás seguro de que deseas restaurar este backup? '
          'Esta acción sobrescribirá los datos actuales del proyecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    // Mostrar diálogo de carga
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restaurando backup del proyecto...'),
          ],
        ),
      ),
    );

    try {
      // Para backups de proyecto, primero descargar el archivo
      final data = await viewModel.downloadBackup(
        backup.driveFileId!,
        BackupType.project,
        fileName: backup.fileName,
      );

      if (!context.mounted) return;
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (data == null || data['bytes'] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error: No se pudo descargar el backup'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Mostrar instrucciones de restauración manual
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup descargado'),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ El backup se ha descargado correctamente.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Para restaurar el proyecto:'),
                  SizedBox(height: 8),
                  Text('1. Extrae el contenido del archivo ZIP'),
                  Text('2. Copia los archivos a la ubicación del proyecto'),
                  Text('3. Reemplaza los archivos existentes si es necesario'),
                  SizedBox(height: 16),
                  Text(
                    '⚠️ Asegúrate de hacer una copia de seguridad del proyecto actual antes de restaurar.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar el diálogo de carga si hay un error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al restaurar el backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
    // Mostrar confirmación antes de eliminar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Backup del Proyecto'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el backup "${backup.fileName}"?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    // Mostrar diálogo de carga
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Eliminando backup del proyecto...'),
          ],
        ),
      ),
    );

    try {
      // Llamar al ViewModel para eliminar el backup
      await viewModel.deleteBackup(
        backup.driveFileId!,
        BackupType.project,
      );

      if (!context.mounted) return;
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar mensaje de éxito o error
      if (viewModel.errorMessage != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${viewModel.errorMessage}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (viewModel.successMessage != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${viewModel.successMessage}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        
        // Recargar la lista de backups
        viewModel.loadBackups(type: BackupType.project);
      }
    } catch (e) {
      // Cerrar el diálogo de carga si hay un error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar el backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
