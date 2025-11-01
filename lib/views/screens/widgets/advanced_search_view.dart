import 'package:flutter/material.dart';
import '../../../models/catalog.dart';

/// Widget para búsqueda avanzada en catálogos
class AdvancedSearchView extends StatefulWidget {
  final List<Catalog> catalogs;
  final Function(List<Catalog>) onResultsChanged;

  const AdvancedSearchView({
    super.key,
    required this.catalogs,
    required this.onResultsChanged,
  });

  @override
  State<AdvancedSearchView> createState() => _AdvancedSearchViewState();
}

class _AdvancedSearchViewState extends State<AdvancedSearchView> {
  final _searchController = TextEditingController();
  String _searchText = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int? _minRows;
  int? _maxRows;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text;
    });
    _performSearch();
  }

  void _performSearch() {
    List<Catalog> results = widget.catalogs;

    // Búsqueda de texto
    if (_searchText.isNotEmpty) {
      results = results.where((catalog) {
        final searchLower = _searchText.toLowerCase();
        return catalog.name.toLowerCase().contains(searchLower) ||
            catalog.description.toLowerCase().contains(searchLower) ||
            // Buscar en filas
            catalog.rows.any((row) =>
                row.data.values.any((value) =>
                    value.toLowerCase().contains(searchLower)));
      }).toList();
    }

    // Filtro por fecha
    if (_startDate != null) {
      results = results.where((catalog) {
        return catalog.createdAt.isAfter(_startDate!) ||
            catalog.createdAt.isAtSameMomentAs(_startDate!);
      }).toList();
    }

    if (_endDate != null) {
      results = results.where((catalog) {
        return catalog.createdAt.isBefore(_endDate!) ||
            catalog.createdAt.isAtSameMomentAs(_endDate!);
      }).toList();
    }

    // Filtro por número de filas
    if (_minRows != null) {
      results = results.where((catalog) {
        return catalog.rows.length >= _minRows!;
      }).toList();
    }

    if (_maxRows != null) {
      results = results.where((catalog) {
        return catalog.rows.length <= _maxRows!;
      }).toList();
    }

    // Filtro por usuario
    if (_selectedUserId != null && _selectedUserId!.isNotEmpty) {
      results = results.where((catalog) {
        return catalog.userId == _selectedUserId;
      }).toList();
    }

    widget.onResultsChanged(results);
  }

  void _clearFilters() {
    setState(() {
      _searchText = '';
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _minRows = null;
      _maxRows = null;
      _selectedUserId = null;
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _searchText.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _minRows != null ||
        _maxRows != null ||
        (_selectedUserId != null && _selectedUserId!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de búsqueda principal
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en catálogos y filas...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Filtros avanzados (expandible)
          ExpansionTile(
            title: const Text(
              'Filtros avanzados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            initiallyExpanded: false,
            children: [
              // Filtros por fecha
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Desde'),
                      subtitle: Text(
                        _startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Seleccionar fecha',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                            _performSearch();
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Hasta'),
                      subtitle: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Seleccionar fecha',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                            _performSearch();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // Filtro por número de filas
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Mín. filas',
                        hintText: 'Ej: 5',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _minRows = value.isEmpty ? null : int.tryParse(value);
                        });
                        _performSearch();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Máx. filas',
                        hintText: 'Ej: 100',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _maxRows = value.isEmpty ? null : int.tryParse(value);
                        });
                        _performSearch();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

