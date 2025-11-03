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
  Future<void> _handleExport(
    BuildContext context,
    Catalog catalog,
    String format,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (format == 'csv') {
        await ExportService.shared.exportAndShareCsv(catalog);
      } else if (format == 'excel') {
        await ExportService.shared.exportAndShareExcel(catalog);
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Catálogo exportado a ${format.toUpperCase()} correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Archivos',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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

    // Construir lista de chips
    final chips = <Widget>[];

    // Agregar imagen singular
    if (row.files.image != null && row.files.image!.isNotEmpty) {
      chips.add(
        _FileChip(
          label: 'Imagen',
          icon: Icons.image,
          onTap: () => onFileTap(row.files.image!, 'Imagen'),
        ),
      );
    }

    // Agregar imágenes múltiples
    for (final url in row.files.images) {
      if (url.isNotEmpty) {
        chips.add(
          _FileChip(
            label: 'Imagen',
            icon: Icons.image,
            onTap: () => onFileTap(url, 'Imagen'),
          ),
        );
      }
    }

    // Agregar documento singular
    if (row.files.document != null && row.files.document!.isNotEmpty) {
      chips.add(
        _FileChip(
          label: 'Documento',
          icon: Icons.description,
          onTap: () => onFileTap(row.files.document!, 'Documento'),
        ),
      );
    }

    // Agregar documentos múltiples
    for (final url in row.files.documents) {
      if (url.isNotEmpty) {
        chips.add(
          _FileChip(
            label: 'Documento',
            icon: Icons.description,
            onTap: () => onFileTap(url, 'Documento'),
          ),
        );
      }
    }

    // Agregar multimedia singular
    if (row.files.multimedia != null && row.files.multimedia!.isNotEmpty) {
      chips.add(
        _FileChip(
          label: 'Multimedia',
          icon: Icons.videocam,
          onTap: () => onFileTap(row.files.multimedia!, 'Multimedia'),
        ),
      );
    }

    // Agregar multimedia múltiple
    for (final url in row.files.multimediaFiles) {
      if (url.isNotEmpty) {
        chips.add(
          _FileChip(
            label: 'Multimedia',
            icon: Icons.videocam,
            onTap: () => onFileTap(url, 'Multimedia'),
          ),
        );
      }
    }

    print('   🎨 Total de chips a mostrar: ${chips.length}');

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
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
            if (row.files.hasAnyFiles) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildFileChips(),
            ],
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

  const _FileChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Chip(
        avatar: Icon(icon, size: 18, color: Colors.blue),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
