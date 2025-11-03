import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/catalog.dart';
import '../../viewmodels/catalog_detail_viewmodel.dart';
import '../../services/export_service.dart';
import '../../services/pagination_service.dart';
import 'widgets/add_edit_row_dialog.dart';
import 'widgets/file_viewer_view.dart';

class CatalogDetailView extends StatefulWidget {
  final Catalog catalog;

  const CatalogDetailView({super.key, required this.catalog});

  @override
  State<CatalogDetailView> createState() => _CatalogDetailViewState();
}

class _CatalogDetailViewState extends State<CatalogDetailView> {
  void _showAllFilesModal(BuildContext context, Catalog catalog) {
    showDialog(
      context: context,
      builder: (context) => _FilesModalDialog(catalog: catalog),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    Catalog catalog,
    String format,
  ) async {
    try {
      // Exportar según el formato usando el nuevo método que abre el diálogo de directorio
      String? filePath;

      // Mostrar diálogo de carga mientras se selecciona el directorio
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
                'Seleccionando directorio para exportar ${format.toUpperCase()}...',
              ),
            ],
          ),
        ),
      );

      if (format == 'csv') {
        filePath = await ExportService.shared.exportAndSaveCsv(catalog);
      } else if (format == 'excel') {
        filePath = await ExportService.shared.exportAndSaveExcel(catalog);
      } else {
        throw Exception('Formato de exportación no soportado: $format');
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading

        if (filePath == null) {
          // Usuario canceló la selección de directorio
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exportación cancelada',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Exportación exitosa
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Catálogo exportado a ${format.toUpperCase()} correctamente',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Archivo: ${filePath.split('/').last}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  'Ubicación: ${filePath.substring(0, filePath.length - filePath.split('/').last.length)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Abrir ubicación',
              textColor: Colors.white,
              onPressed: () {
                // Abrir el directorio en Finder (macOS)
                if (Platform.isMacOS && filePath != null) {
                  final fileName = filePath.split('/').last;
                  final directory = filePath.substring(
                    0,
                    filePath.length - fileName.length - 1,
                  );
                  Process.run('open', [directory]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading si aún está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al exportar: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CatalogDetailViewModel(catalog: widget.catalog),
      child: Consumer<CatalogDetailViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(viewModel.catalog.name),
              actions: [
                // Botón de exportar
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download),
                  tooltip: 'Exportar',
                  onSelected: (value) =>
                      _handleExport(context, viewModel.catalog, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, size: 20),
                          SizedBox(width: 8),
                          Text('Exportar a CSV'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.schema, size: 20),
                          SizedBox(width: 8),
                          Text('Exportar a Excel'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(viewModel.isEditing ? Icons.check : Icons.edit),
                  onPressed: () {
                    viewModel.toggleEditing();
                  },
                  tooltip: viewModel.isEditing ? 'Terminar edición' : 'Editar',
                ),
                if (viewModel.isEditing)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      viewModel.showAddRowSheet();
                    },
                    tooltip: 'Añadir fila',
                  ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    // Descripción
                    if (viewModel.catalog.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          viewModel.catalog.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    if (viewModel.catalog.description.isNotEmpty)
                      const Divider(),
                    // Cabecera de columnas con ordenamiento
                    if (viewModel.catalog.columns.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...viewModel.catalog.columns.map((column) {
                                final isSorted =
                                    viewModel.sortedColumn == column;
                                return _SortableColumnHeader(
                                  title: column,
                                  isSorted: isSorted,
                                  sortDirection: isSorted
                                      ? viewModel.sortDirection
                                      : SortDirection.none,
                                  onTap: () {
                                    viewModel.toggleSort(column);
                                  },
                                );
                              }),
                              InkWell(
                                onTap: () => _showAllFilesModal(
                                  context,
                                  viewModel.catalog,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Archivos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new,
                                        size: 14,
                                        color: Colors.blue.shade700,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Contenido
                    Expanded(
                      child: viewModel.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : viewModel.errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Error al cargar filas',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    viewModel.errorMessage!,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => viewModel.reloadCatalog(),
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            )
                          : viewModel.totalRows == 0
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No hay filas disponibles',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Añade nuevas filas para comenzar',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  if (viewModel.isEditing)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        viewModel.showAddRowSheet();
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Añadir fila'),
                                    ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Información de paginación de filas
                                if (viewModel.totalRows >
                                    viewModel.itemsPerPage)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    color: Colors.grey.shade100,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${viewModel.rowsRange} filas',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_left,
                                              ),
                                              onPressed:
                                                  PaginationService.hasPreviousPage(
                                                    viewModel.currentPage,
                                                  )
                                                  ? () =>
                                                        viewModel.previousPage()
                                                  : null,
                                              tooltip: 'Página anterior',
                                            ),
                                            Text(
                                              'Página ${viewModel.currentPage} de ${viewModel.totalPages}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_right,
                                              ),
                                              onPressed:
                                                  PaginationService.hasNextPage(
                                                    viewModel.currentPage,
                                                    viewModel.totalPages,
                                                  )
                                                  ? () => viewModel.nextPage()
                                                  : null,
                                              tooltip: 'Página siguiente',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                // Lista de filas
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: viewModel.rows.length,
                                    itemBuilder: (context, index) {
                                      final row = viewModel.rows[index];
                                      return _CatalogRowCard(
                                        row: row,
                                        columns: viewModel.catalog.columns,
                                        index: index,
                                        isEditing: viewModel.isEditing,
                                        onEdit: () {
                                          _showEditRowDialog(
                                            context,
                                            viewModel,
                                            index,
                                            row,
                                          );
                                        },
                                        onDelete: () {
                                          _showDeleteConfirmation(
                                            context,
                                            viewModel,
                                            index,
                                          );
                                        },
                                        onFileTap: (url, fileName) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FileViewerView(
                                                    url: url,
                                                    fileName: fileName,
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                // Diálogo para añadir/editar fila
                if (viewModel.showingAddRowSheet)
                  AddEditRowDialog(
                    catalog: viewModel.catalog,
                    onSave: (data, files) {
                      viewModel.addRow(data, files);
                      viewModel.hideAddRowSheet();
                    },
                    onCancel: () {
                      viewModel.hideAddRowSheet();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditRowDialog(
    BuildContext context,
    CatalogDetailViewModel viewModel,
    int index,
    CatalogRow row,
  ) {
    showDialog(
      context: context,
      builder: (context) => AddEditRowDialog(
        catalog: viewModel.catalog,
        row: row,
        onSave: (data, files) {
          viewModel.updateRow(index, data, files);
          Navigator.of(context).pop();
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    CatalogDetailViewModel viewModel,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar fila'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta fila? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteRow(index);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _SortableColumnHeader extends StatelessWidget {
  final String title;
  final bool isSorted;
  final SortDirection sortDirection;
  final VoidCallback onTap;

  const _SortableColumnHeader({
    required this.title,
    required this.isSorted,
    required this.sortDirection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    Color? color;

    switch (sortDirection) {
      case SortDirection.ascending:
        icon = Icons.arrow_upward;
        color = Colors.blue;
        break;
      case SortDirection.descending:
        icon = Icons.arrow_downward;
        color = Colors.blue;
        break;
      case SortDirection.none:
        icon = Icons.unfold_more;
        color = Colors.grey;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSorted ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSorted ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: isSorted ? FontWeight.bold : FontWeight.normal,
                color: isSorted ? Colors.blue.shade700 : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _CatalogRowCard extends StatelessWidget {
  final CatalogRow row;
  final List<String> columns;
  final int index;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String url, String fileName) onFileTap;

  _CatalogRowCard({
    required this.row,
    required this.columns,
    required this.index,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.onFileTap,
  });

  Widget _buildFileChips() {
    // Debug: verificar archivos de la fila
    print('📋 Mostrando archivos de fila:');
    print('   image: ${row.files.image}');
    print('   images (${row.files.images.length}): ${row.files.images}');
    print('   document: ${row.files.document}');
    print(
      '   documents (${row.files.documents.length}): ${row.files.documents}',
    );
    print('   multimedia: ${row.files.multimedia}');
    print(
      '   multimediaFiles (${row.files.multimediaFiles.length}): ${row.files.multimediaFiles}',
    );

    // Construir listas separadas por tipo
    final imageChips = <Widget>[];
    final documentChips = <Widget>[];
    final multimediaChips = <Widget>[];

    // Agregar imagen singular
    if (row.files.image != null && row.files.image!.isNotEmpty) {
      final url = row.files.image!;
      final title = row.files.fileTitles[url] ?? '';
      imageChips.add(
        _FileChip(
          label: title.isEmpty ? 'Imagen' : title,
          icon: Icons.image,
          showTypeIcon: true,
          fileType: 'Imagen',
          onTap: () => onFileTap(url, 'Imagen'),
        ),
      );
    }

    // Agregar imágenes múltiples
    for (final url in row.files.images) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        imageChips.add(
          _FileChip(
            label: title.isEmpty ? 'Imagen' : title,
            icon: Icons.image,
            showTypeIcon: true,
            fileType: 'Imagen',
            onTap: () => onFileTap(url, 'Imagen'),
          ),
        );
      }
    }

    // Agregar documento singular
    if (row.files.document != null && row.files.document!.isNotEmpty) {
      final url = row.files.document!;
      final title = row.files.fileTitles[url] ?? '';
      documentChips.add(
        _FileChip(
          label: title.isEmpty ? 'Documento' : title,
          icon: Icons.description,
          showTypeIcon: true,
          fileType: 'Documento',
          onTap: () => onFileTap(url, 'Documento'),
        ),
      );
    }

    // Agregar documentos múltiples
    for (final url in row.files.documents) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        documentChips.add(
          _FileChip(
            label: title.isEmpty ? 'Documento' : title,
            icon: Icons.description,
            showTypeIcon: true,
            fileType: 'Documento',
            onTap: () => onFileTap(url, 'Documento'),
          ),
        );
      }
    }

    // Agregar multimedia singular
    if (row.files.multimedia != null && row.files.multimedia!.isNotEmpty) {
      final url = row.files.multimedia!;
      final title = row.files.fileTitles[url] ?? '';
      multimediaChips.add(
        _FileChip(
          label: title.isEmpty ? 'Multimedia' : title,
          icon: Icons.videocam,
          showTypeIcon: true,
          fileType: 'Multimedia',
          onTap: () => onFileTap(url, 'Multimedia'),
        ),
      );
    }

    // Agregar multimedia múltiple
    for (final url in row.files.multimediaFiles) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        multimediaChips.add(
          _FileChip(
            label: title.isEmpty ? 'Multimedia' : title,
            icon: Icons.videocam,
            showTypeIcon: true,
            fileType: 'Multimedia',
            onTap: () => onFileTap(url, 'Multimedia'),
          ),
        );
      }
    }

    final totalChips =
        imageChips.length + documentChips.length + multimediaChips.length;
    print('   🎨 Total de chips a mostrar: $totalChips');

    if (totalChips == 0) {
      return const SizedBox.shrink();
    }

    // Construir lista de secciones con separadores usando Column
    final sections = <Widget>[];

    // Sección de imágenes
    if (imageChips.isNotEmpty) {
      sections.add(Wrap(spacing: 8, runSpacing: 8, children: imageChips));
    }

    // Separador entre imágenes y documentos
    if (imageChips.isNotEmpty && documentChips.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
    }

    // Sección de documentos
    if (documentChips.isNotEmpty) {
      sections.add(Wrap(spacing: 8, runSpacing: 8, children: documentChips));
    }

    // Separador entre documentos y multimedia
    if (documentChips.isNotEmpty && multimediaChips.isNotEmpty) {
      sections.add(const SizedBox(height: 12));
    }

    // Sección de multimedia
    if (multimediaChips.isNotEmpty) {
      sections.add(Wrap(spacing: 8, runSpacing: 8, children: multimediaChips));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: columns.map((column) {
                        final value = row.data[column] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          constraints: const BoxConstraints(minWidth: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                column,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(value, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.blue,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            // Archivos
            Builder(
              builder: (context) {
                final hasFiles = row.files.hasAnyFiles;
                print(
                  '🔍 Verificando archivos para fila $index: hasAnyFiles=$hasFiles',
                );
                if (!hasFiles) {
                  print(
                    '   ⚠️ Fila $index NO tiene archivos o hasAnyFiles retorna false',
                  );
                  print('     image: ${row.files.image}');
                  print('     images: ${row.files.images}');
                  print('     document: ${row.files.document}');
                  print('     documents: ${row.files.documents}');
                  print('     multimedia: ${row.files.multimedia}');
                  print('     multimediaFiles: ${row.files.multimediaFiles}');
                }
                if (hasFiles) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildFileChips(),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool showTypeIcon;
  final String? fileType;

  const _FileChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.showTypeIcon = false,
    this.fileType,
  });

  IconData _getTypeIcon() {
    switch (fileType) {
      case 'Imagen':
        return Icons.image;
      case 'Documento':
        return Icons.description;
      case 'Multimedia':
        return Icons.videocam;
      default:
        return icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Chip(
        avatar: showTypeIcon
            ? Icon(_getTypeIcon(), size: 18, color: Colors.blue)
            : Icon(icon, size: 18, color: Colors.blue),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showTypeIcon && fileType != null) ...[
              const SizedBox(width: 4),
              Icon(_getTypeIcon(), size: 14, color: Colors.grey.shade600),
            ],
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Clase auxiliar para representar un archivo en el modal
class _FileItem {
  final String url;
  final String title;
  final int rowNumber;

  _FileItem({required this.url, required this.title, required this.rowNumber});
}

/// Modal que primero muestra la lista de filas y luego los archivos de la fila seleccionada
class _FilesModalDialog extends StatefulWidget {
  final Catalog catalog;

  const _FilesModalDialog({required this.catalog});

  @override
  State<_FilesModalDialog> createState() => _FilesModalDialogState();
}

class _FilesModalDialogState extends State<_FilesModalDialog> {
  CatalogRow? _selectedRow;
  int? _selectedRowIndex;

  void _selectRow(CatalogRow row, int index) {
    setState(() {
      _selectedRow = row;
      _selectedRowIndex = index;
    });
  }

  void _goBack() {
    setState(() {
      _selectedRow = null;
      _selectedRowIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_selectedRow != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _goBack,
                        tooltip: 'Volver a la lista de filas',
                      ),
                    Text(
                      _selectedRow != null
                          ? 'Archivos de la Fila ${_selectedRowIndex! + 1}'
                          : 'Seleccionar Fila',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // Contenido
            Expanded(
              child: _selectedRow == null
                  ? _buildRowsList()
                  : _buildRowFiles(_selectedRow!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowsList() {
    if (widget.catalog.rows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay filas en este catálogo',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.catalog.rows.length,
      itemBuilder: (context, index) {
        final row = widget.catalog.rows[index];
        final hasFiles = row.files.hasAnyFiles;
        final fileCount = _getFileCount(row.files);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: hasFiles ? Colors.blue : Colors.grey,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'Fila ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              hasFiles
                  ? '$fileCount archivo${fileCount > 1 ? 's' : ''}'
                  : 'Sin archivos',
              style: TextStyle(
                color: hasFiles ? Colors.green : Colors.grey,
                fontWeight: hasFiles ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            trailing: hasFiles
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (row.files.image != null ||
                          row.files.images.isNotEmpty)
                        Icon(Icons.image, color: Colors.blue, size: 20),
                      if (row.files.document != null ||
                          row.files.documents.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.description, color: Colors.orange, size: 20),
                      ],
                      if (row.files.multimedia != null ||
                          row.files.multimediaFiles.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.videocam, color: Colors.red, size: 20),
                      ],
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  )
                : const Icon(Icons.chevron_right),
            enabled: hasFiles,
            onTap: hasFiles ? () => _selectRow(row, index) : null,
          ),
        );
      },
    );
  }

  int _getFileCount(RowFiles files) {
    int count = 0;
    if (files.image != null && files.image!.isNotEmpty) count++;
    count += files.images.length;
    if (files.document != null && files.document!.isNotEmpty) count++;
    count += files.documents.length;
    if (files.multimedia != null && files.multimedia!.isNotEmpty) count++;
    count += files.multimediaFiles.length;
    return count;
  }

  Widget _buildRowFiles(CatalogRow row) {
    // Recopilar archivos de la fila por categorías
    final imageFiles = <_FileItem>[];
    final documentFiles = <_FileItem>[];
    final multimediaFiles = <_FileItem>[];

    // Imágenes
    if (row.files.image != null && row.files.image!.isNotEmpty) {
      final url = row.files.image!;
      final title = row.files.fileTitles[url] ?? '';
      imageFiles.add(
        _FileItem(
          url: url,
          title: title.isEmpty ? 'Imagen' : title,
          rowNumber: _selectedRowIndex! + 1,
        ),
      );
    }
    for (final url in row.files.images) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        imageFiles.add(
          _FileItem(
            url: url,
            title: title.isEmpty ? 'Imagen' : title,
            rowNumber: _selectedRowIndex! + 1,
          ),
        );
      }
    }

    // Documentos
    if (row.files.document != null && row.files.document!.isNotEmpty) {
      final url = row.files.document!;
      final title = row.files.fileTitles[url] ?? '';
      documentFiles.add(
        _FileItem(
          url: url,
          title: title.isEmpty ? 'Documento' : title,
          rowNumber: _selectedRowIndex! + 1,
        ),
      );
    }
    for (final url in row.files.documents) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        documentFiles.add(
          _FileItem(
            url: url,
            title: title.isEmpty ? 'Documento' : title,
            rowNumber: _selectedRowIndex! + 1,
          ),
        );
      }
    }

    // Multimedia
    if (row.files.multimedia != null && row.files.multimedia!.isNotEmpty) {
      final url = row.files.multimedia!;
      final title = row.files.fileTitles[url] ?? '';
      multimediaFiles.add(
        _FileItem(
          url: url,
          title: title.isEmpty ? 'Multimedia' : title,
          rowNumber: _selectedRowIndex! + 1,
        ),
      );
    }
    for (final url in row.files.multimediaFiles) {
      if (url.isNotEmpty) {
        final title = row.files.fileTitles[url] ?? '';
        multimediaFiles.add(
          _FileItem(
            url: url,
            title: title.isEmpty ? 'Multimedia' : title,
            rowNumber: _selectedRowIndex! + 1,
          ),
        );
      }
    }

    // Si no hay archivos, mostrar mensaje
    if (imageFiles.isEmpty &&
        documentFiles.isEmpty &&
        multimediaFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Esta fila no tiene archivos',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección de imágenes
          if (imageFiles.isNotEmpty) ...[
            _FileCategorySection(
              title: 'Imágenes',
              icon: Icons.image,
              iconColor: Colors.blue,
              files: imageFiles,
              onFileTap: (file) =>
                  _openFileViewer(context, file.url, file.title),
            ),
            const SizedBox(height: 24),
          ],
          // Sección de documentos
          if (documentFiles.isNotEmpty) ...[
            _FileCategorySection(
              title: 'Documentos',
              icon: Icons.description,
              iconColor: Colors.orange,
              files: documentFiles,
              onFileTap: (file) =>
                  _openFileViewer(context, file.url, file.title),
            ),
            const SizedBox(height: 24),
          ],
          // Sección de multimedia
          if (multimediaFiles.isNotEmpty) ...[
            _FileCategorySection(
              title: 'Multimedia',
              icon: Icons.videocam,
              iconColor: Colors.red,
              files: multimediaFiles,
              onFileTap: (file) =>
                  _openFileViewer(context, file.url, file.title),
            ),
          ],
        ],
      ),
    );
  }

  void _openFileViewer(BuildContext context, String url, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerView(url: url, fileName: fileName),
      ),
    );
  }
}

/// Widget para mostrar una sección de archivos por categoría
class _FileCategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_FileItem> files;
  final Function(_FileItem) onFileTap;

  const _FileCategorySection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.files,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de la categoría
        Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${files.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Lista de archivos
        ...files.map(
          (file) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(
                file.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Fila ${file.rowNumber}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onFileTap(file),
            ),
          ),
        ),
      ],
    );
  }
}
