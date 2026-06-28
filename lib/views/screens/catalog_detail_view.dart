import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/catalog.dart';
import '../../utils/app_theme.dart';
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
      String? filePath;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'Seleccionando directorio para exportar ${format.toUpperCase()}...',
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          );
        },
      );

      if (format == 'csv') {
        filePath = await ExportService.shared.exportAndSaveCsv(catalog);
      } else if (format == 'excel') {
        filePath = await ExportService.shared.exportAndSaveExcel(catalog);
      } else {
        throw Exception('Formato de exportación no soportado: $format');
      }

      if (context.mounted) {
        Navigator.of(context).pop();

        if (filePath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Exportación cancelada')),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
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
                if (!kIsWeb)
                  Text(
                    'Ubicación: ${filePath.substring(0, filePath.length - filePath.split('/').last.length)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text(
                    'Descargado en la carpeta de descargas',
                    style: TextStyle(fontSize: 10, color: Colors.white60),
                  ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Abrir',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isMacOS && filePath != null) {
                  final fileName = filePath.split('/').last;
                  final directory = filePath.substring(
                      0, filePath.length - fileName.length - 1);
                  Process.run('open', [directory]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al exportar: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
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
          final cs = Theme.of(context).colorScheme;

          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viewModel.catalog.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  if (viewModel.totalRows > 0)
                    Text(
                      '${viewModel.totalRows} fila${viewModel.totalRows != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
              actions: [
                // Exportar
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Exportar',
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium)),
                  onSelected: (value) =>
                      _handleExport(context, viewModel.catalog, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_rounded,
                              size: 20, color: cs.primary),
                          const SizedBox(width: 12),
                          const Text('Exportar a CSV'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.grid_on_rounded,
                              size: 20, color: cs.primary),
                          const SizedBox(width: 12),
                          const Text('Exportar a Excel'),
                        ],
                      ),
                    ),
                  ],
                ),
                // Editar / Confirmar edición
                IconButton(
                  icon: Icon(
                    viewModel.isEditing
                        ? Icons.check_rounded
                        : Icons.edit_rounded,
                    color: viewModel.isEditing ? cs.primary : null,
                  ),
                  onPressed: viewModel.toggleEditing,
                  tooltip: viewModel.isEditing ? 'Terminar edición' : 'Editar',
                ),
                // Añadir fila (solo en modo edición)
                if (viewModel.isEditing)
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: viewModel.showAddRowSheet,
                    tooltip: 'Añadir fila',
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    // Descripción del catálogo
                    if (viewModel.catalog.description.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        color: cs.surfaceContainerLow,
                        child: Text(
                          viewModel.catalog.description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.75),
                            height: 1.5,
                          ),
                        ),
                      ),

                    // Cabecera de columnas
                    if (viewModel.catalog.columns.isNotEmpty)
                      _ColumnHeaderBar(
                        columns: viewModel.catalog.columns,
                        sortedColumn: viewModel.sortedColumn,
                        sortDirection: viewModel.sortDirection,
                        onColumnTap: viewModel.toggleSort,
                        onFilesTap: () =>
                            _showAllFilesModal(context, viewModel.catalog),
                      ),

                    // Contenido principal
                    Expanded(
                      child: viewModel.isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: cs.primary))
                          : viewModel.errorMessage != null
                              ? _ErrorState(
                                  message: viewModel.errorMessage!,
                                  onRetry: viewModel.reloadCatalog,
                                )
                              : viewModel.totalRows == 0
                                  ? _EmptyState(
                                      isEditing: viewModel.isEditing,
                                      onAdd: viewModel.showAddRowSheet,
                                    )
                                  : Column(
                                      children: [
                                        // Paginación
                                        if (viewModel.totalRows >
                                            viewModel.itemsPerPage)
                                          _PaginationBar(
                                            rowsRange: viewModel.rowsRange,
                                            currentPage: viewModel.currentPage,
                                            totalPages: viewModel.totalPages,
                                            onPrevious:
                                                PaginationService.hasPreviousPage(
                                                        viewModel.currentPage)
                                                    ? viewModel.previousPage
                                                    : null,
                                            onNext:
                                                PaginationService.hasNextPage(
                                                        viewModel.currentPage,
                                                        viewModel.totalPages)
                                                    ? viewModel.nextPage
                                                    : null,
                                          ),
                                        // Lista de filas
                                        Expanded(
                                          child: ListView.builder(
                                            padding: const EdgeInsets.all(16),
                                            itemCount: viewModel.rows.length,
                                            itemBuilder: (context, index) {
                                              final row =
                                                  viewModel.rows[index];
                                              return _CatalogRowCard(
                                                row: row,
                                                columns:
                                                    viewModel.catalog.columns,
                                                index: index,
                                                isEditing: viewModel.isEditing,
                                                onEdit: () =>
                                                    _showEditRowDialog(
                                                        context,
                                                        viewModel,
                                                        index,
                                                        row),
                                                onDelete: () =>
                                                    _showDeleteConfirmation(
                                                        context,
                                                        viewModel,
                                                        index),
                                                onFileTap: (url, fileName) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          FileViewerView(
                                                              url: url,
                                                              fileName:
                                                                  fileName),
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

                // Overlay de añadir fila
                if (viewModel.showingAddRowSheet)
                  AddEditRowDialog(
                    catalog: viewModel.catalog,
                    onSave: (data, files) {
                      viewModel.addRow(data, files);
                      viewModel.hideAddRowSheet();
                    },
                    onCancel: viewModel.hideAddRowSheet,
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
      builder: (_) => AddEditRowDialog(
        catalog: viewModel.catalog,
        row: row,
        onSave: (data, files) {
          viewModel.updateRow(index, data, files);
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    CatalogDetailViewModel viewModel,
    int index,
  ) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.delete_rounded, color: cs.error, size: 28),
        title: Text('Eliminar fila',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta fila? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              viewModel.deleteRow(index);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Barra de cabeceras de columna ─────────────────────────────────────────────
class _ColumnHeaderBar extends StatelessWidget {
  final List<String> columns;
  final String? sortedColumn;
  final SortDirection sortDirection;
  final ValueChanged<String> onColumnTap;
  final VoidCallback onFilesTap;

  const _ColumnHeaderBar({
    required this.columns,
    required this.sortedColumn,
    required this.sortDirection,
    required this.onColumnTap,
    required this.onFilesTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...columns.map((col) {
              final isSorted = sortedColumn == col;
              IconData sortIcon;
              if (!isSorted) {
                sortIcon = Icons.unfold_more_rounded;
              } else if (sortDirection == SortDirection.ascending) {
                sortIcon = Icons.arrow_upward_rounded;
              } else {
                sortIcon = Icons.arrow_downward_rounded;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(col,
                          style: GoogleFonts.inter(
                              fontWeight: isSorted
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13,
                              color: cs.onSurface)),
                      const SizedBox(width: 4),
                      Icon(sortIcon, size: 14,
                          color: isSorted
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.45)),
                    ],
                  ),
                  selected: isSorted,
                  onSelected: (_) => onColumnTap(col),
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSorted ? cs.primary : cs.outlineVariant,
                  ),
                  backgroundColor: isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerLowest,
                  selectedColor: isDark
                      ? cs.primaryContainer.withValues(alpha: 0.8)
                      : cs.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }),
            // Botón "Archivos"
            ActionChip(
              avatar: Icon(Icons.folder_open_rounded,
                  size: 16, color: cs.primary),
              label: Text('Archivos',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface)),
              onPressed: onFilesTap,
              side: BorderSide(color: cs.primary.withValues(alpha: isDark ? 0.6 : 0.4)),
              backgroundColor: isDark
                  ? cs.surfaceContainerHigh
                  : cs.primaryContainer.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barra de paginación ───────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final String rowsRange;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.rowsRange,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rowsRange,
            style: GoogleFonts.inter(
                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: onPrevious,
                tooltip: 'Página anterior',
                iconSize: 20,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: onNext,
                tooltip: 'Página siguiente',
                iconSize: 20,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onAdd;

  const _EmptyState({required this.isEditing, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
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
              child: Icon(Icons.table_rows_rounded,
                  size: 36, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin filas todavía',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Añade nuevas filas para comenzar a gestionar el catálogo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
            if (isEditing) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir primera fila'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Estado de error ───────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: cs.onErrorContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'Error al cargar filas',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de fila de catálogo ───────────────────────────────────────────────
class _CatalogRowCard extends StatelessWidget {
  final CatalogRow row;
  final List<String> columns;
  final int index;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String url, String fileName) onFileTap;

  const _CatalogRowCard({
    required this.row,
    required this.columns,
    required this.index,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.onFileTap,
  });

  Widget _buildFileChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Debug logs mantenidos del original
    print('📋 Mostrando archivos de fila:');
    print('   image: ${row.files.image}');
    print('   images (${row.files.images.length}): ${row.files.images}');
    print('   document: ${row.files.document}');
    print('   documents (${row.files.documents.length}): ${row.files.documents}');
    print('   multimedia: ${row.files.multimedia}');
    print('   multimediaFiles (${row.files.multimediaFiles.length}): ${row.files.multimediaFiles}');

    final imageChips = <Widget>[];
    final documentChips = <Widget>[];
    final multimediaChips = <Widget>[];

    void addChip(
        List<Widget> list, String url, String fallback, IconData icon) {
      final title = row.files.fileTitles[url] ?? '';
      final label = title.isEmpty ? fallback : title;
      list.add(_FileChip(
        label: label,
        icon: icon,
        onTap: () => onFileTap(url, label),
        cs: cs,
      ));
    }

    if (row.files.image != null && row.files.image!.isNotEmpty) {
      addChip(imageChips, row.files.image!, 'Imagen', Icons.image_rounded);
    }
    for (final url in row.files.images) {
      if (url.isNotEmpty) {
        addChip(imageChips, url, 'Imagen', Icons.image_rounded);
      }
    }
    if (row.files.document != null && row.files.document!.isNotEmpty) {
      addChip(documentChips, row.files.document!, 'Documento',
          Icons.description_rounded);
    }
    for (final url in row.files.documents) {
      if (url.isNotEmpty) {
        addChip(documentChips, url, 'Documento', Icons.description_rounded);
      }
    }
    if (row.files.multimedia != null && row.files.multimedia!.isNotEmpty) {
      addChip(multimediaChips, row.files.multimedia!, 'Multimedia',
          Icons.videocam_rounded);
    }
    for (final url in row.files.multimediaFiles) {
      if (url.isNotEmpty) {
        addChip(multimediaChips, url, 'Multimedia', Icons.videocam_rounded);
      }
    }

    final total =
        imageChips.length + documentChips.length + multimediaChips.length;
    print('   🎨 Total de chips a mostrar: $total');
    if (total == 0) return const SizedBox.shrink();

    final sections = <Widget>[];
    if (imageChips.isNotEmpty) {
      sections.add(Wrap(spacing: 8, runSpacing: 6, children: imageChips));
    }
    if (imageChips.isNotEmpty && documentChips.isNotEmpty) {
      sections.add(const SizedBox(height: 8));
    }
    if (documentChips.isNotEmpty) {
      sections.add(Wrap(spacing: 8, runSpacing: 6, children: documentChips));
    }
    if (documentChips.isNotEmpty && multimediaChips.isNotEmpty) {
      sections.add(const SizedBox(height: 8));
    }
    if (multimediaChips.isNotEmpty) {
      sections
          .add(Wrap(spacing: 8, runSpacing: 6, children: multimediaChips));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número de fila + datos + botones de acción
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Índice
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Campos de datos
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: columns.map((col) {
                        final value = row.data[col] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(right: 20),
                          constraints: const BoxConstraints(minWidth: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                col,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                value.isEmpty ? '—' : value,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: value.isEmpty
                                      ? cs.onSurface.withValues(alpha: 0.3)
                                      : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Botones edición
                if (isEditing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: cs.primary,
                    onPressed: onEdit,
                    tooltip: 'Editar fila',
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    color: cs.error,
                    onPressed: onDelete,
                    tooltip: 'Eliminar fila',
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: cs.errorContainer.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            // Archivos adjuntos
            Builder(builder: (context) {
              final hasFiles = row.files.hasAnyFiles;
              print(
                  '🔍 Verificando archivos para fila $index: hasAnyFiles=$hasFiles');
              if (!hasFiles) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Divider(color: cs.outlineVariant, height: 1),
                  const SizedBox(height: 10),
                  _buildFileChips(context),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Chip de archivo ───────────────────────────────────────────────────────────
class _FileChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _FileChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: cs.primary),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: onTap,
      side: BorderSide(color: cs.primary.withValues(alpha: isDark ? 0.6 : 0.3)),
      backgroundColor: isDark
          ? cs.surfaceContainerHigh
          : cs.primaryContainer.withValues(alpha: 0.25),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Clase auxiliar para el modal de archivos ──────────────────────────────────
class _FileItem {
  final String url;
  final String title;
  final int rowNumber;
  _FileItem({required this.url, required this.title, required this.rowNumber});
}

// ── Modal de archivos (lista de filas → archivos de fila) ─────────────────────
class _FilesModalDialog extends StatefulWidget {
  final Catalog catalog;
  const _FilesModalDialog({required this.catalog});

  @override
  State<_FilesModalDialog> createState() => _FilesModalDialogState();
}

class _FilesModalDialogState extends State<_FilesModalDialog> {
  CatalogRow? _selectedRow;
  int? _selectedRowIndex;

  void _selectRow(CatalogRow row, int index) =>
      setState(() { _selectedRow = row; _selectedRowIndex = index; });
  void _goBack() =>
      setState(() { _selectedRow = null; _selectedRowIndex = null; });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(isNarrow ? 12 : 20),
        child: Column(
          children: [
            // Encabezado
            Row(
              children: [
                if (_selectedRow != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _goBack,
                    tooltip: 'Volver',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_selectedRow != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedRow != null
                        ? 'Archivos · Fila ${_selectedRowIndex! + 1}'
                        : 'Seleccionar fila',
                    style: GoogleFonts.inter(
                        fontSize: isNarrow ? 16 : 20,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 4),
            // Contenido
            Expanded(
              child: _selectedRow == null
                  ? _buildRowsList(context, cs)
                  : _buildRowFiles(context, cs, _selectedRow!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowsList(BuildContext context, ColorScheme cs) {
    if (widget.catalog.rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 56,
                color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No hay filas en este catálogo',
                style: GoogleFonts.inter(
                    fontSize: 15, color: cs.onSurface.withValues(alpha: 0.55))),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: widget.catalog.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final row = widget.catalog.rows[index];
        final hasFiles = row.files.hasAnyFiles;
        final fileCount = _getFileCount(row.files);

        return ListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          tileColor: cs.surfaceContainerLow,
          leading: CircleAvatar(
            backgroundColor: hasFiles ? cs.primaryContainer : cs.surfaceContainerHighest,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: hasFiles ? cs.onPrimaryContainer : cs.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ),
          title: Text('Fila ${index + 1}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          subtitle: Text(
            hasFiles
                ? '$fileCount archivo${fileCount > 1 ? 's' : ''}'
                : 'Sin archivos',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: hasFiles
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          trailing: hasFiles
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row.files.image != null || row.files.images.isNotEmpty)
                      Icon(Icons.image_rounded, color: cs.primary, size: 18),
                    if (row.files.document != null ||
                        row.files.documents.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.description_rounded,
                          color: cs.tertiary, size: 18),
                    ],
                    if (row.files.multimedia != null ||
                        row.files.multimediaFiles.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.videocam_rounded,
                          color: cs.error, size: 18),
                    ],
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ],
                )
              : Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.2)),
          enabled: hasFiles,
          onTap: hasFiles ? () => _selectRow(row, index) : null,
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

  Widget _buildRowFiles(
      BuildContext context, ColorScheme cs, CatalogRow row) {
    final imageFiles = <_FileItem>[];
    final documentFiles = <_FileItem>[];
    final multimediaFiles = <_FileItem>[];

    void addItem(List<_FileItem> list, String url, String fallback) {
      final title = row.files.fileTitles[url] ?? '';
      list.add(_FileItem(
        url: url,
        title: title.isEmpty ? fallback : title,
        rowNumber: _selectedRowIndex! + 1,
      ));
    }

    if (row.files.image != null && row.files.image!.isNotEmpty) {
      addItem(imageFiles, row.files.image!, 'Imagen');
    }
    for (final url in row.files.images) {
      if (url.isNotEmpty) addItem(imageFiles, url, 'Imagen');
    }
    if (row.files.document != null && row.files.document!.isNotEmpty) {
      addItem(documentFiles, row.files.document!, 'Documento');
    }
    for (final url in row.files.documents) {
      if (url.isNotEmpty) addItem(documentFiles, url, 'Documento');
    }
    if (row.files.multimedia != null && row.files.multimedia!.isNotEmpty) {
      addItem(multimediaFiles, row.files.multimedia!, 'Multimedia');
    }
    for (final url in row.files.multimediaFiles) {
      if (url.isNotEmpty) addItem(multimediaFiles, url, 'Multimedia');
    }

    if (imageFiles.isEmpty &&
        documentFiles.isEmpty &&
        multimediaFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 56,
                color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Esta fila no tiene archivos',
                style: GoogleFonts.inter(
                    fontSize: 15, color: cs.onSurface.withValues(alpha: 0.55))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageFiles.isNotEmpty)
            _FileCategorySection(
              title: 'Imágenes',
              icon: Icons.image_rounded,
              iconColor: cs.primary,
              files: imageFiles,
              cs: cs,
              onFileTap: (f) => _openFileViewer(context, f.url, f.title),
            ),
          if (imageFiles.isNotEmpty && documentFiles.isNotEmpty)
            const SizedBox(height: 20),
          if (documentFiles.isNotEmpty)
            _FileCategorySection(
              title: 'Documentos',
              icon: Icons.description_rounded,
              iconColor: cs.tertiary,
              files: documentFiles,
              cs: cs,
              onFileTap: (f) => _openFileViewer(context, f.url, f.title),
            ),
          if (documentFiles.isNotEmpty && multimediaFiles.isNotEmpty)
            const SizedBox(height: 20),
          if (multimediaFiles.isNotEmpty)
            _FileCategorySection(
              title: 'Multimedia',
              icon: Icons.videocam_rounded,
              iconColor: cs.error,
              files: multimediaFiles,
              cs: cs,
              onFileTap: (f) => _openFileViewer(context, f.url, f.title),
            ),
        ],
      ),
    );
  }

  void _openFileViewer(BuildContext context, String url, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              FileViewerView(url: url, fileName: fileName)),
    );
  }
}

// ── Sección de categoría de archivos en el modal ──────────────────────────────
class _FileCategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_FileItem> files;
  final ColorScheme cs;
  final Function(_FileItem) onFileTap;

  const _FileCategorySection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.files,
    required this.cs,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text('${files.length}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...files.map(
          (file) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium)),
              leading: Icon(icon, color: iconColor, size: 20),
              title: Text(file.title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: Text('Fila ${file.rowNumber}',
                  style: GoogleFonts.inter(fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4)),
              onTap: () => onFileTap(file),
            ),
          ),
        ),
      ],
    );
  }
}
