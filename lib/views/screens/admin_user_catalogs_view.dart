import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/user.dart' show User;
import '../../services/mongo_service.dart';
import 'catalog_detail_view.dart';

/// Pantalla de administración: catálogos asignados a un usuario concreto.
///
/// Equivalente Flutter de AdminUserCatalogsView.swift (EDFCatalogoSwift).
///
/// Mejoras respecto a la versión Swift:
///   - Carga real desde MongoDB via MongoService (Swift usaba datos hardcoded)
///   - Muestra objetos Catalog completos (nombre, descripción, nº de filas)
///   - Búsqueda por nombre y descripción
///   - Menú contextual con "Ver detalles" (→ CatalogDetailView) y "Eliminar"
///   - Pull-to-refresh
///
/// Uso:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => AdminUserCatalogsView(user: selectedUser),
/// ));
/// ```
class AdminUserCatalogsView extends StatefulWidget {
  final User user;

  const AdminUserCatalogsView({super.key, required this.user});

  @override
  State<AdminUserCatalogsView> createState() => _AdminUserCatalogsViewState();
}

class _AdminUserCatalogsViewState extends State<AdminUserCatalogsView> {
  final _searchController = TextEditingController();

  List<Catalog> _catalogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Carga de datos
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadCatalogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalogs = await MongoService().getCatalogs(
        widget.user.id,
        isAdmin: false, // Catálogos del usuario, no todos
        userEmail: widget.user.email,
      );
      if (mounted) {
        setState(() {
          _catalogs = catalogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Acciones
  // ──────────────────────────────────────────────────────────────────────────

  List<Catalog> get _filteredCatalogs {
    if (_searchText.isEmpty) return _catalogs;
    final q = _searchText.toLowerCase();
    return _catalogs.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  void _openDetail(Catalog catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CatalogDetailView(catalog: catalog)),
    );
  }

  Future<void> _confirmDelete(Catalog catalog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar catálogo'),
        content: Text(
          '¿Seguro que quieres eliminar "${catalog.name}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await MongoService().deleteCatalog(catalog.id);
      setState(() => _catalogs.remove(catalog));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catálogo "${catalog.name}" eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catálogos del usuario'),
            Text(
              widget.user.email,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar catálogo…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (v) => setState(() => _searchText = v),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando catálogos…'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildError(theme);
    }

    final items = _filteredCatalogs;

    if (items.isEmpty) {
      return _buildEmpty(theme);
    }

    return RefreshIndicator(
      onRefresh: _loadCatalogs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _CatalogCard(
          catalog: items[i],
          onViewDetails: () => _openDetail(items[i]),
          onDelete: () => _confirmDelete(items[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    final isFiltered = _searchText.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? Icons.search_off : Icons.library_books_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'Sin resultados' : 'Sin catálogos',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'No hay catálogos que coincidan con "$_searchText"'
                : 'Este usuario no tiene catálogos asignados',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('Error al cargar catálogos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadCatalogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tarjeta de catálogo
// ────────────────────────────────────────────────────────────────────────────

class _CatalogCard extends StatelessWidget {
  final Catalog catalog;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  const _CatalogCard({
    required this.catalog,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowCount = catalog.rows.length;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              // Icono
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),

              // Nombre + descripción + recuento
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (catalog.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        catalog.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '$rowCount ${rowCount == 1 ? 'elemento' : 'elementos'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Menú contextual (equivalente al Menu de SwiftUI)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'details') onViewDetails();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Ver detalles'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
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
