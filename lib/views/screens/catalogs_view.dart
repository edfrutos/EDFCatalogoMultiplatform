import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/catalog_viewmodel.dart';
import '../../models/catalog.dart';
import '../../services/pagination_service.dart';
import 'catalog_detail_view.dart';
import 'profile_view.dart';
import 'widgets/create_catalog_dialog.dart';
import 'widgets/edit_catalog_dialog.dart';
import 'widgets/advanced_search_view.dart';

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

  // Paginación
  int _currentPage = 1;
  static const int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // El listener se agregará dentro del Consumer cuando tengamos acceso a los catálogos
  }

  void _onScroll(List<Catalog> allCatalogs) {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9) {
      // Cargar más cuando se acerca al final (90%)
      _loadMoreItems(allCatalogs);
    }
  }

  void _loadMoreItems(List<Catalog> allCatalogs) {
    if (_isLoadingMore) return;

    final allFiltered = _getAllFilteredCatalogs(allCatalogs);
    final totalPages = PaginationService.calculateTotalPages(
      allFiltered.length,
      _itemsPerPage,
    );

    if (PaginationService.hasNextPage(_currentPage, totalPages)) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });

      // Simular carga (en producción esto podría ser una llamada a la API)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  void _updateFilteredCatalogs(List<Catalog> filtered) {
    setState(() {
      _filteredCatalogs = filtered;
    });
  }

  List<Catalog> _getFilteredCatalogs(List<Catalog> catalogs) {
    List<Catalog> filtered;

    // Si se está usando búsqueda avanzada, usar resultados filtrados
    if (_useAdvancedSearch && _filteredCatalogs.isNotEmpty) {
      filtered = _filteredCatalogs;
    } else if (_searchText.isEmpty) {
      // Sin búsqueda
      filtered = catalogs;
    } else {
      // Búsqueda simple
      filtered = catalogs.where((catalog) {
        final searchLower = _searchText.toLowerCase();
        return catalog.name.toLowerCase().contains(searchLower) ||
            catalog.description.toLowerCase().contains(searchLower) ||
            // Buscar dentro de las filas
            catalog.rows.any(
              (row) => row.data.values.any(
                (value) => value.toLowerCase().contains(searchLower),
              ),
            );
      }).toList();
    }

    // Aplicar paginación
    return PaginationService.getPageItems(
      filtered,
      _currentPage,
      _itemsPerPage,
    );
  }

  List<Catalog> _getAllFilteredCatalogs(List<Catalog> catalogs) {
    // Retorna todos los catálogos filtrados sin paginación (para cálculos)
    if (_useAdvancedSearch && _filteredCatalogs.isNotEmpty) {
      return _filteredCatalogs;
    }

    if (_searchText.isEmpty) {
      return catalogs;
    }

    return catalogs.where((catalog) {
      final searchLower = _searchText.toLowerCase();
      return catalog.name.toLowerCase().contains(searchLower) ||
          catalog.description.toLowerCase().contains(searchLower) ||
          catalog.rows.any(
            (row) => row.data.values.any(
              (value) => value.toLowerCase().contains(searchLower),
            ),
          );
    }).toList();
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
    });
  }

  void _onSearchChanged(String value) {
    _resetPagination();
    setState(() {
      _searchText = value;
      _useAdvancedSearch = false;
    });
  }

  void _onAdvancedSearchChanged(List<Catalog> filtered) {
    _resetPagination();
    _updateFilteredCatalogs(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final currentUser = authViewModel.currentUser;

    return ChangeNotifierProvider(
      create: (_) => CatalogViewModel()
        ..loadCatalogs(
          userId: currentUser?.id ?? '',
          isAdmin: currentUser?.isAdmin ?? false,
          userEmail: currentUser?.email,
        ),
      child: Consumer<CatalogViewModel>(
        builder: (context, catalogViewModel, _) {
          final allFilteredCatalogs = _getAllFilteredCatalogs(
            catalogViewModel.catalogs,
          );
          final paginatedCatalogs = _getFilteredCatalogs(
            catalogViewModel.catalogs,
          );
          final totalPages = PaginationService.calculateTotalPages(
            allFilteredCatalogs.length,
            _itemsPerPage,
          );
          final itemsRange = PaginationService.getItemsRange(
            _currentPage,
            _itemsPerPage,
            allFilteredCatalogs.length,
          );

          final isMobile = MediaQuery.of(context).size.width < 600;

          return Scaffold(
            body: Column(
              children: [
                // Header - Responsive
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primera fila: Título y botón nuevo
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Catálogos',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (catalogViewModel.isOffline)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.cloud_off,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Modo offline',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Botón nuevo catálogo
                          if (currentUser != null)
                            isMobile
                                ? IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            CreateCatalogDialog(
                                              onCreate:
                                                  (name, description, columns) {
                                                    catalogViewModel
                                                        .createCatalog(
                                                          name: name,
                                                          description:
                                                              description,
                                                          userId:
                                                              currentUser.id,
                                                          columns: columns,
                                                        );
                                                  },
                                            ),
                                      );
                                    },
                                    tooltip: 'Nuevo catálogo',
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            CreateCatalogDialog(
                                              onCreate:
                                                  (name, description, columns) {
                                                    catalogViewModel
                                                        .createCatalog(
                                                          name: name,
                                                          description:
                                                              description,
                                                          userId:
                                                              currentUser.id,
                                                          columns: columns,
                                                        );
                                                  },
                                            ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nuevo'),
                                  ),
                        ],
                      ),
                      // Segunda fila: Perfil y sincronizar (solo en móvil si no hay espacio)
                      if (currentUser != null && !isMobile) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileView(),
                                  ),
                                );
                              },
                              icon: currentUser.profileImageUrl != null
                                  ? CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.transparent,
                                      backgroundImage:
                                          CachedNetworkImageProvider(
                                            currentUser.profileImageUrl!,
                                          ),
                                    )
                                  : CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.blue,
                                      child: Text(
                                        currentUser.name.isNotEmpty
                                            ? currentUser.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                              label: Text(currentUser.name),
                            ),
                            if (catalogViewModel.isOffline) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.sync),
                                onPressed: () {
                                  catalogViewModel.syncPendingData(
                                    userId: currentUser.id,
                                    isAdmin: currentUser.isAdmin,
                                    userEmail: currentUser.email,
                                  );
                                },
                                tooltip: 'Sincronizar',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Búsqueda avanzada o simple
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Buscar catálogos y filas...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchText.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchText = '';
                                            _useAdvancedSearch = false;
                                            _filteredCatalogs = [];
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        _useAdvancedSearch
                                            ? Icons.filter_alt
                                            : Icons.filter_alt_outlined,
                                        color: _useAdvancedSearch
                                            ? Theme.of(context).primaryColor
                                            : null,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _useAdvancedSearch =
                                              !_useAdvancedSearch;
                                          if (!_useAdvancedSearch) {
                                            _filteredCatalogs = [];
                                          }
                                        });
                                      },
                                      tooltip: 'Búsqueda avanzada',
                                    ),
                                  ],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey[200]
                                    : Colors.grey[800],
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                        ],
                      ),
                      if (_useAdvancedSearch) ...[
                        const SizedBox(height: 8),
                        AdvancedSearchView(
                          catalogs: catalogViewModel.catalogs,
                          onResultsChanged: _onAdvancedSearchChanged,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Lista de catálogos
                Expanded(
                  child: catalogViewModel.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : catalogViewModel.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                catalogViewModel.error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  if (currentUser != null) {
                                    catalogViewModel.loadCatalogs(
                                      userId: currentUser.id,
                                      isAdmin: currentUser.isAdmin,
                                      userEmail: currentUser.email,
                                    );
                                  }
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : paginatedCatalogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchText.isEmpty
                                    ? Icons.folder_outlined
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchText.isEmpty
                                    ? 'No hay catálogos'
                                    : 'No se encontraron catálogos',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_searchText.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Intenta con otros términos de búsqueda',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollEndNotification) {
                              _onScroll(catalogViewModel.catalogs);
                            }
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
                                // Información de paginación
                                if (allFilteredCatalogs.length > _itemsPerPage)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    color: Colors.grey.shade100,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            itemsRange,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.chevron_left,
                                                ),
                                                onPressed:
                                                    PaginationService.hasPreviousPage(
                                                      _currentPage,
                                                    )
                                                    ? () {
                                                        setState(() {
                                                          _currentPage--;
                                                        });
                                                        _scrollController
                                                            .animateTo(
                                                              0,
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),
                                                              curve: Curves
                                                                  .easeOut,
                                                            );
                                                      }
                                                    : null,
                                                tooltip: 'Página anterior',
                                              ),
                                              Text(
                                                'Página $_currentPage de $totalPages',
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
                                                      _currentPage,
                                                      totalPages,
                                                    )
                                                    ? () {
                                                        setState(() {
                                                          _currentPage++;
                                                        });
                                                        _scrollController
                                                            .animateTo(
                                                              0,
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),
                                                              curve: Curves
                                                                  .easeOut,
                                                            );
                                                      }
                                                    : null,
                                                tooltip: 'Página siguiente',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Lista de catálogos
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount:
                                        paginatedCatalogs.length +
                                        (_isLoadingMore ? 1 : 0) +
                                        (PaginationService.hasNextPage(
                                                  _currentPage,
                                                  totalPages,
                                                ) &&
                                                !_isLoadingMore
                                            ? 1
                                            : 0),
                                    itemBuilder: (context, index) {
                                      // Botón de cargar más
                                      if (index == paginatedCatalogs.length) {
                                        if (_isLoadingMore) {
                                          return const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        } else if (PaginationService.hasNextPage(
                                          _currentPage,
                                          totalPages,
                                        )) {
                                          return Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                _loadMoreItems(
                                                  catalogViewModel.catalogs,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.expand_more,
                                              ),
                                              label: const Text('Cargar más'),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }

                                      final catalog = paginatedCatalogs[index];

                                      final displayImageUrl = catalog
                                          .getDisplayImageUrl();

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: ListTile(
                                          leading: displayImageUrl != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: CachedNetworkImage(
                                                    imageUrl: displayImageUrl,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Container(
                                                          width: 60,
                                                          height: 60,
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          ),
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          width: 60,
                                                          height: 60,
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          child: const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 30,
                                                          ),
                                                        ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 30,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          title: Text(
                                            catalog.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                          subtitle: Text(
                                            catalog.description,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                color: Colors.blue,
                                                onPressed: () {
                                                  _showEditCatalogDialog(
                                                    context,
                                                    catalog,
                                                    catalogViewModel,
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text(
                                                        'Eliminar Catálogo',
                                                      ),
                                                      content: Text(
                                                        '¿Estás seguro de que quieres eliminar "${catalog.name}"? Esta acción no se puede deshacer.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            catalogViewModel
                                                                .deleteCatalog(
                                                                  catalogId:
                                                                      catalog
                                                                          .id,
                                                                );
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                          style:
                                                              TextButton.styleFrom(
                                                                foregroundColor:
                                                                    Colors.red,
                                                              ),
                                                          child: const Text(
                                                            'Eliminar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    CatalogDetailView(
                                                      catalog: catalog,
                                                    ),
                                              ),
                                            );
                                          },
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

  /// Mostrar diálogo para editar un catálogo
  void _showEditCatalogDialog(
    BuildContext context,
    Catalog catalog,
    CatalogViewModel catalogViewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => EditCatalogDialog(
        catalog: catalog,
        onSave: (name, description, columns, thumbnailUrl) async {
          final success = await catalogViewModel.updateCatalog(
            catalog: catalog,
            name: name,
            description: description,
            columns: columns,
            thumbnailUrl: thumbnailUrl,
          );

          if (context.mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Catálogo actualizado correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '❌ Error al actualizar: ${catalogViewModel.error ?? "Error desconocido"}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}
