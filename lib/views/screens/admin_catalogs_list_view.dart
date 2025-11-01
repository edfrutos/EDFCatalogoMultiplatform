import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/mongo_service.dart';
import '../../models/catalog.dart';
import 'catalog_detail_view.dart';

class AdminCatalogsListView extends StatefulWidget {
  const AdminCatalogsListView({super.key});

  @override
  State<AdminCatalogsListView> createState() => _AdminCatalogsListViewState();
}

class _AdminCatalogsListViewState extends State<AdminCatalogsListView> {
  final _searchController = TextEditingController();
  String _searchText = '';
  List<Catalog> _catalogs = [];
  bool _isLoading = false;

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

  Future<void> _loadCatalogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;

      if (user != null) {
        _catalogs = await MongoService().getCatalogs(
          user.id,
          isAdmin: user.isAdmin,
          userEmail: user.email,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar catálogos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Catalog> _getFilteredCatalogs() {
    if (_searchText.isEmpty) {
      return _catalogs;
    }
    return _catalogs.where((catalog) {
      return catalog.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          catalog.description.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCatalogs = _getFilteredCatalogs();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestión de Catálogos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: ${_catalogs.length} catálogos',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.blue,
                onPressed: _isLoading ? null : _loadCatalogs,
              ),
            ],
          ),
        ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o descripción',
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
        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando catálogos...'),
                    ],
                  ),
                )
              : filteredCatalogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchText.isEmpty
                            ? Icons.library_books_outlined
                            : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchText.isEmpty
                            ? 'Sin catálogos'
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
                  onRefresh: _loadCatalogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredCatalogs.length,
                    itemBuilder: (context, index) {
                      final catalog = filteredCatalogs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.library_books),
                          title: Text(catalog.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(catalog.description),
                              const SizedBox(height: 4),
                              Text(
                                '${catalog.rows.length} filas • ${catalog.columns.length} columnas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    CatalogDetailView(catalog: catalog),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
