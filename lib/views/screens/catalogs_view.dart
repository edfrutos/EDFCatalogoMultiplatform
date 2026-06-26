import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/catalog_viewmodel.dart';
import '../../models/catalog.dart';
import '../../services/pagination_service.dart';
import 'catalog_detail_view.dart';
import 'profile_view.dart';
import 'widgets/create_catalog_dialog.dart';
import 'widgets/edit_catalog_dialog.dart';
import 'widgets/advanced_search_view.dart';
import 'widgets/lazy_image_widget.dart';
import 'widgets/s3_presigned_widget.dart';

class CatalogsView extends StatefulWidget {
  const CatalogsView({super.key});

  @override
  State<CatalogsView> createState() => _CatalogsViewState();
}

class _CatalogsViewState extends State<CatalogsView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchText = '';
  List<Catalog> _filteredCatalogs = [];
  bool _useAdvancedSearch = false;

  int _currentPage = 1;
  static const int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  void _onScroll(List<Catalog> allCatalogs) {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems(allCatalogs);
    }
  }

  void _loadMoreItems(List<Catalog> allCatalogs) {
    if (_isLoadingMore) return;
    final allFiltered = _getAllFilteredCatalogs(allCatalogs);
    final totalPages = PaginationService.calculateTotalPages(allFiltered.length, _itemsPerPage);
    if (PaginationService.hasNextPage(_currentPage, totalPages)) {
      setState(() { _isLoadingMore = true; _currentPage++; });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() { _isLoadingMore = false; });
      });
    }
  }

  List<Catalog> _getFilteredCatalogs(List<Catalog> catalogs) {
    List<Catalog> filtered;
    if (_useAdvancedSearch && _filteredCatalogs.isNotEmpty) {
      filtered = _filteredCatalogs;
    } else if (_searchText.isEmpty) {
      filtered = catalogs;
    } else {
      final q = _searchText.toLowerCase();
      filtered = catalogs.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.rows.any((r) => r.data.values.any((v) => v.toLowerCase().contains(q)))).toList();
    }
    return PaginationService.getPageItems(filtered, _currentPage, _itemsPerPage);
  }

  List<Catalog> _getAllFilteredCatalogs(List<Catalog> catalogs) {
    if (_useAdvancedSearch && _filteredCatalogs.isNotEmpty) return _filteredCatalogs;
    if (_searchText.isEmpty) return catalogs;
    final q = _searchText.toLowerCase();
    return catalogs.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.description.toLowerCase().contains(q) ||
      c.rows.any((r) => r.data.values.any((v) => v.toLowerCase().contains(q)))).toList();
  }

  void _resetPagination() => setState(() => _currentPage = 1);

  void _onSearchChanged(String value) {
    _resetPagination();
    setState(() { _searchText = value; _useAdvancedSearch = false; });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final currentUser = authViewModel.currentUser;
    final cs = Theme.of(context).colorScheme;

    return ChangeNotifierProvider(
      create: (_) => CatalogViewModel()
        ..loadCatalogs(
          userId: currentUser?.id ?? '',
          isAdmin: currentUser?.isAdmin ?? false,
          userEmail: currentUser?.email,
        ),
      child: Consumer<CatalogViewModel>(
        builder: (context, catalogViewModel, _) {
          final allFiltered = _getAllFilteredCatalogs(catalogViewModel.catalogs);
          final paginated = _getFilteredCatalogs(catalogViewModel.catalogs);
          final totalPages = PaginationService.calculateTotalPages(allFiltered.length, _itemsPerPage);
          final itemsRange = PaginationService.getItemsRange(_currentPage, _itemsPerPage, allFiltered.length);
          final isMobile = MediaQuery.of(context).size.width < 600;

          return Scaffold(
            backgroundColor: cs.surface,
            body: Column(
              children: [
                // ── Header ───────────────────────────────────────────────────
                Container(
                  color: cs.surface,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catálogos',
                                  style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (catalogViewModel.isOffline)
                                  Row(
                                    children: [
                                      Icon(Icons.cloud_off_rounded, size: 12, color: cs.error),
                                      const SizedBox(width: 4),
                                      Text('Modo offline',
                                          style: GoogleFonts.inter(
                                            fontSize: 12, color: cs.error, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                if (!catalogViewModel.isOffline && !catalogViewModel.isLoading)
                                  Text(
                                    '${catalogViewModel.catalogs.length} catálogo${catalogViewModel.catalogs.length != 1 ? 's' : ''}',
                                    style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          // Perfil + nuevo catálogo
                          if (currentUser != null) ...[
                            if (!isMobile) ...[
                              _ProfileChip(currentUser: currentUser),
                              const SizedBox(width: 8),
                            ],
                            if (catalogViewModel.isOffline)
                              IconButton(
                                icon: const Icon(Icons.sync_rounded),
                                onPressed: () => catalogViewModel.syncPendingData(
                                  userId: currentUser.id,
                                  isAdmin: currentUser.isAdmin,
                                  userEmail: currentUser.email,
                                ),
                                tooltip: 'Sincronizar',
                              ),
                            _buildNewCatalogButton(context, catalogViewModel, currentUser, isMobile),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      // ── Búsqueda ──────────────────────────────────────────
                      _SearchBar(
                        controller: _searchController,
                        searchText: _searchText,
                        useAdvanced: _useAdvancedSearch,
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                            _useAdvancedSearch = false;
                            _filteredCatalogs = [];
                          });
                          _resetPagination();
                        },
                        onToggleAdvanced: () {
                          setState(() {
                            _useAdvancedSearch = !_useAdvancedSearch;
                            if (!_useAdvancedSearch) _filteredCatalogs = [];
                          });
                        },
                      ),
                      if (_useAdvancedSearch) ...[
                        const SizedBox(height: 8),
                        AdvancedSearchView(
                          catalogs: catalogViewModel.catalogs,
                          onResultsChanged: (filtered) {
                            _resetPagination();
                            setState(() => _filteredCatalogs = filtered);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: cs.outlineVariant),
                // ── Lista ─────────────────────────────────────────────────────
                Expanded(
                  child: catalogViewModel.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : catalogViewModel.error != null
                          ? _ErrorState(
                              error: catalogViewModel.error!,
                              onRetry: () {
                                if (currentUser != null) {
                                  catalogViewModel.loadCatalogs(
                                    userId: currentUser.id,
                                    isAdmin: currentUser.isAdmin,
                                    userEmail: currentUser.email,
                                  );
                                }
                              },
                            )
                          : paginated.isEmpty
                              ? _EmptyState(hasSearch: _searchText.isNotEmpty || _useAdvancedSearch)
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n is ScrollEndNotification) _onScroll(catalogViewModel.catalogs);
                                    return false;
                                  },
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      _resetPagination();
                                      if (currentUser != null) {
                                        await catalogViewModel.loadCatalogs(
                                          userId: currentUser.id,
                                          isAdmin: currentUser.isAdmin,
                                          userEmail: currentUser.email,
                                        );
                                      }
                                    },
                                    child: Column(
                                      children: [
                                        // Paginación info
                                        if (allFiltered.length > _itemsPerPage)
                                          _PaginationBar(
                                            itemsRange: itemsRange,
                                            currentPage: _currentPage,
                                            totalPages: totalPages,
                                            onPrev: PaginationService.hasPreviousPage(_currentPage)
                                                ? () {
                                                    setState(() => _currentPage--);
                                                    _scrollController.animateTo(0,
                                                        duration: const Duration(milliseconds: 250),
                                                        curve: Curves.easeOut);
                                                  }
                                                : null,
                                            onNext: PaginationService.hasNextPage(_currentPage, totalPages)
                                                ? () {
                                                    setState(() => _currentPage++);
                                                    _scrollController.animateTo(0,
                                                        duration: const Duration(milliseconds: 250),
                                                        curve: Curves.easeOut);
                                                  }
                                                : null,
                                          ),
                                        // Lista de cards
                                        Expanded(
                                          child: ListView.builder(
                                            controller: _scrollController,
                                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                            itemCount: paginated.length +
                                                (_isLoadingMore ? 1 : 0) +
                                                (PaginationService.hasNextPage(_currentPage, totalPages) && !_isLoadingMore ? 1 : 0),
                                            itemBuilder: (context, index) {
                                              if (index == paginated.length) {
                                                if (_isLoadingMore) {
                                                  return const Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child: Center(child: CircularProgressIndicator()),
                                                  );
                                                } else if (PaginationService.hasNextPage(_currentPage, totalPages)) {
                                                  return Padding(
                                                    padding: const EdgeInsets.all(16),
                                                    child: FilledButton.tonal(
                                                      onPressed: () => _loadMoreItems(catalogViewModel.catalogs),
                                                      child: const Text('Cargar más'),
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              }

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: _CatalogCard(
                                                  catalog: paginated[index],
                                                  onTap: () => Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => CatalogDetailView(catalog: paginated[index]),
                                                    ),
                                                  ),
                                                  onEdit: () => _showEditDialog(context, paginated[index], catalogViewModel),
                                                  onDelete: () => _showDeleteDialog(context, paginated[index], catalogViewModel),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewCatalogButton(BuildContext context, CatalogViewModel vm, dynamic user, bool isMobile) {
    void create() => showDialog(
      context: context,
      builder: (_) => CreateCatalogDialog(
        onCreate: (name, desc, cols) => vm.createCatalog(
          name: name, description: desc, userId: user.id, columns: cols,
        ),
      ),
    );

    if (isMobile) {
      return FilledButton.icon(
        onPressed: create,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nuevo'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: create,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Nuevo catálogo'),
    );
  }

  void _showEditDialog(BuildContext context, Catalog catalog, CatalogViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => EditCatalogDialog(
        catalog: catalog,
        onSave: (name, desc, cols, thumb) async {
          final ok = await vm.updateCatalog(
            catalog: catalog, name: name, description: desc, columns: cols, thumbnailUrl: thumb,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? '✅ Catálogo actualizado' : '❌ Error: ${vm.error ?? "desconocido"}'),
              backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
            ));
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Catalog catalog, CatalogViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar catálogo'),
        content: Text('¿Eliminar "${catalog.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              vm.deleteCatalog(catalogId: catalog.id);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de catálogo ────────────────────────────────────────────────────────
class _CatalogCard extends StatelessWidget {
  final Catalog catalog;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CatalogCard({
    required this.catalog,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = catalog.getDisplayImageUrl();
    final rowCount = catalog.rows.length;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: imageUrl != null
                      ? LazyImageWidget(
                          imageUrl: imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: _ThumbPlaceholder(cs: cs),
                          errorWidget: _ThumbPlaceholder(cs: cs),
                        )
                      : _ThumbPlaceholder(cs: cs),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (catalog.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        catalog.description,
                        style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Chips de info
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.table_rows_outlined,
                          label: '$rowCount fila${rowCount != 1 ? 's' : ''}',
                          cs: cs,
                        ),
                        if (catalog.columns.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _InfoChip(
                            icon: Icons.view_column_outlined,
                            label: '${catalog.columns.length} col.',
                            cs: cs,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Acciones
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primaryContainer.withOpacity(0.4),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                    style: IconButton.styleFrom(
                      backgroundColor: cs.errorContainer.withOpacity(0.3),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
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

class _ThumbPlaceholder extends StatelessWidget {
  final ColorScheme cs;
  const _ThumbPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.photo_outlined, color: cs.onSurfaceVariant.withOpacity(0.5), size: 28),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _InfoChip({required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Barra de búsqueda ──────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchText;
  final bool useAdvanced;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onToggleAdvanced;

  const _SearchBar({
    required this.controller,
    required this.searchText,
    required this.useAdvanced,
    required this.onChanged,
    required this.onClear,
    required this.onToggleAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Buscar en catálogos y filas…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (searchText.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
                tooltip: 'Limpiar',
              ),
            Tooltip(
              message: 'Búsqueda avanzada',
              child: IconButton(
                icon: Icon(
                  useAdvanced ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                  size: 18,
                  color: useAdvanced ? cs.primary : null,
                ),
                onPressed: onToggleAdvanced,
              ),
            ),
          ],
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// ── Chip de perfil ─────────────────────────────────────────────────────────────
class _ProfileChip extends StatelessWidget {
  final dynamic currentUser;
  const _ProfileChip({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: currentUser.profileImageUrl != null
          ? S3PresignedBuilder(
              rawUrl: currentUser.profileImageUrl!,
              loadingWidget: _InitialAvatar(name: currentUser.name, cs: cs, radius: 12),
              errorWidget: _InitialAvatar(name: currentUser.name, cs: cs, radius: 12),
              builder: (context, url) => CircleAvatar(
                radius: 12,
                backgroundImage: CachedNetworkImageProvider(url),
              ),
            )
          : _InitialAvatar(name: currentUser.name, cs: cs, radius: 12),
      label: Text(
        currentUser.name,
        style: GoogleFonts.inter(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileView()),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final ColorScheme cs;
  final double radius;
  const _InitialAvatar({required this.name, required this.cs, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.inter(fontSize: radius * 0.9, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Barra de paginación ────────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final String itemsRange;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.itemsRange,
    required this.currentPage,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(itemsRange, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: onPrev,
            visualDensity: VisualDensity.compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$currentPage / $totalPages',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.folder_open_rounded,
              size: 40,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch ? 'Sin resultados' : 'Sin catálogos',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch ? 'Prueba con otros términos de búsqueda' : 'Crea tu primer catálogo con el botón "Nuevo"',
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Estado de error ────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 16),
          Text(
            error,
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
