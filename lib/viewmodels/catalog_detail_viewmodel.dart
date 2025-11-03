import 'package:flutter/foundation.dart';
import '../models/catalog.dart';
import '../services/mongo_service.dart';
import '../services/pagination_service.dart';

enum SortDirection { none, ascending, descending }

class CatalogDetailViewModel extends ChangeNotifier {
  final MongoService _mongoService = MongoService.shared;

  Catalog _catalog;
  List<CatalogRow> _rows = [];
  List<CatalogRow> _originalRows = [];

  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditing = false;
  bool _showingAddRowSheet = false;

  String? _sortedColumn;
  SortDirection _sortDirection = SortDirection.none;

  // Paginación de filas
  int _currentPage = 1;
  static const int _itemsPerPage = 50;

  Catalog get catalog => _catalog;
  List<CatalogRow> get rows => _rows;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEditing => _isEditing;
  bool get showingAddRowSheet => _showingAddRowSheet;
  String? get sortedColumn => _sortedColumn;
  SortDirection get sortDirection => _sortDirection;

  // Getters de paginación
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalRows => _originalRows.length;
  int get totalPages => PaginationService.calculateTotalPages(
    _originalRows.length,
    _itemsPerPage,
  );
  String get rowsRange => PaginationService.getItemsRange(
    _currentPage,
    _itemsPerPage,
    _originalRows.length,
  );

  CatalogDetailViewModel({required Catalog catalog}) : _catalog = catalog {
    _loadRows();
  }

  void _loadRows() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Cargar filas del catálogo
      _originalRows = List.from(_catalog.rows);

      // Si no hay filas pero hay legacyRows, convertirlas
      if (_originalRows.isEmpty && _catalog.legacyRows != null) {
        // legacyRows es Map<String, dynamic> que puede tener diferentes estructuras
        // Si es una lista de maps, convertir directamente
        if (_catalog.legacyRows is List) {
          final legacyList = _catalog.legacyRows as List;
          _originalRows = legacyList.map((legacyRow) {
            final rowData = <String, String>{};
            if (legacyRow is Map) {
              legacyRow.forEach((key, value) {
                rowData[key.toString()] = value.toString();
              });
            }
            return CatalogRow(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              originalId: DateTime.now().millisecondsSinceEpoch.toString(),
              data: rowData,
              files: RowFiles(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }).toList();
        } else if (_catalog.legacyRows is Map) {
          // Si es un Map, cada entrada puede ser una fila
          final legacyMap = _catalog.legacyRows as Map;
          _originalRows = legacyMap.values.map((legacyRow) {
            final rowData = <String, String>{};
            if (legacyRow is Map) {
              legacyRow.forEach((key, value) {
                rowData[key.toString()] = value.toString();
              });
            }
            return CatalogRow(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              originalId: DateTime.now().millisecondsSinceEpoch.toString(),
              data: rowData,
              files: RowFiles(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }).toList();
        }
      }

      _applySorting();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar filas: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applySorting() {
    List<CatalogRow> sortedRows;

    if (_sortedColumn == null || _sortDirection == SortDirection.none) {
      sortedRows = List.from(_originalRows);
    } else {
      sortedRows = List.from(_originalRows);
      sortedRows.sort((row1, row2) {
        final value1 = row1.data[_sortedColumn] ?? '';
        final value2 = row2.data[_sortedColumn] ?? '';

        // Intentar ordenar numéricamente si ambos valores son números
        final num1 = double.tryParse(value1);
        final num2 = double.tryParse(value2);

        if (num1 != null && num2 != null) {
          return _sortDirection == SortDirection.ascending
              ? num1.compareTo(num2)
              : num2.compareTo(num1);
        }

        // Ordenamiento alfabético
        final comparison = value1.toLowerCase().compareTo(value2.toLowerCase());
        return _sortDirection == SortDirection.ascending
            ? comparison
            : -comparison;
      });
    }

    // Aplicar paginación a las filas ordenadas
    _rows = PaginationService.getPageItems(
      sortedRows,
      _currentPage,
      _itemsPerPage,
    );
    notifyListeners();
  }

  void nextPage() {
    if (PaginationService.hasNextPage(_currentPage, totalPages)) {
      _currentPage++;
      _applySorting();
    }
  }

  void previousPage() {
    if (PaginationService.hasPreviousPage(_currentPage)) {
      _currentPage--;
      _applySorting();
    }
  }

  void goToPage(int page) {
    final totalPages = PaginationService.calculateTotalPages(
      _originalRows.length,
      _itemsPerPage,
    );
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      _applySorting();
    }
  }

  void resetPagination() {
    _currentPage = 1;
    _applySorting();
  }

  void toggleSort(String column) {
    if (_sortedColumn == column) {
      // Cambiar dirección
      switch (_sortDirection) {
        case SortDirection.none:
          _sortDirection = SortDirection.ascending;
          break;
        case SortDirection.ascending:
          _sortDirection = SortDirection.descending;
          break;
        case SortDirection.descending:
          _sortDirection = SortDirection.none;
          _sortedColumn = null;
          break;
      }
    } else {
      // Nueva columna, empezar con ascendente
      _sortedColumn = column;
      _sortDirection = SortDirection.ascending;
    }
    _applySorting();
  }

  void toggleEditing() {
    _isEditing = !_isEditing;
    if (!_isEditing) {
      // Al salir del modo edición, guardar cambios
      _persistCatalogChanges();
    }
    notifyListeners();
  }

  void showAddRowSheet() {
    _showingAddRowSheet = true;
    notifyListeners();
  }

  void hideAddRowSheet() {
    _showingAddRowSheet = false;
    notifyListeners();
  }

  void addRow(Map<String, String> data, RowFiles files) {
    final now = DateTime.now();
    final newRow = CatalogRow(
      id: now.millisecondsSinceEpoch.toString(),
      originalId: now.millisecondsSinceEpoch.toString(),
      data: data,
      files: files,
      createdAt: now,
      updatedAt: now,
    );

    _originalRows.add(newRow);
    // Si se agrega una nueva fila, puede que necesitemos ir a la última página
    final totalPages = PaginationService.calculateTotalPages(
      _originalRows.length,
      _itemsPerPage,
    );
    if (totalPages > _currentPage) {
      _currentPage = totalPages;
    }
    _applySorting();
    _persistCatalogChanges();
  }

  void updateRow(int index, Map<String, String> data, RowFiles files) {
    if (index < 0 || index >= _rows.length) return;

    print('🔄 Actualizando fila en índice $index');
    print('   Archivos recibidos:');
    print('     image: ${files.image}');
    print('     images: ${files.images}');
    print('     document: ${files.document}');
    print('     documents: ${files.documents}');
    print('     multimedia: ${files.multimedia}');
    print('     multimediaFiles: ${files.multimediaFiles}');
    print('     hasAnyFiles: ${files.hasAnyFiles}');

    // Obtener la fila desde rows (ya ordenada)
    final updatedRow = CatalogRow(
      id: _rows[index].id,
      originalId: _rows[index].originalId,
      data: data,
      files: files,
      createdAt: _rows[index].createdAt,
      updatedAt: DateTime.now(),
    );

    // Actualizar en originalRows usando el originalId
    final originalIndex = _originalRows.indexWhere(
      (r) => r.originalId == updatedRow.originalId,
    );
    if (originalIndex != -1) {
      _originalRows[originalIndex] = updatedRow;
      print('✅ Fila actualizada en originalRows[${originalIndex}]');
      print(
        '   Archivos después de actualizar: hasAnyFiles=${updatedRow.files.hasAnyFiles}',
      );
    } else {
      print(
        '⚠️ No se encontró la fila en originalRows con originalId=${updatedRow.originalId}',
      );
    }

    _applySorting();
    _persistCatalogChanges();
  }

  void deleteRow(int index) {
    if (index < 0 || index >= _rows.length) return;

    // Obtener la fila a eliminar desde rows (ya ordenada)
    final rowToDelete = _rows[index];

    // Eliminar de originalRows usando el originalId
    _originalRows.removeWhere((r) => r.originalId == rowToDelete.originalId);

    _applySorting();
    _persistCatalogChanges();
  }

  Future<void> reloadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedCatalog = await _mongoService.getCatalogById(_catalog.id);
      if (updatedCatalog != null) {
        _catalog = updatedCatalog;
        _loadRows();
      } else {
        _errorMessage = 'No se pudo recargar el catálogo';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al recargar: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistCatalogChanges() async {
    // Actualizar el catálogo con las filas originales (sin ordenamiento)
    final updatedCatalog = Catalog(
      id: _catalog.id,
      name: _catalog.name,
      description: _catalog.description,
      userId: _catalog.userId,
      columns: _catalog.columns,
      rows: _originalRows,
      legacyRows: _catalog.legacyRows,
      createdAt: _catalog.createdAt,
      updatedAt: DateTime.now(),
    );

    _catalog = updatedCatalog;

    try {
      print('💾 Guardando catálogo en MongoDB...');
      print('   Total de filas: ${_originalRows.length}');
      for (int i = 0; i < _originalRows.length; i++) {
        final row = _originalRows[i];
        print('   Fila $i: hasAnyFiles=${row.files.hasAnyFiles}');
        if (row.files.hasAnyFiles) {
          print('     image: ${row.files.image}, images: ${row.files.images}');
          print(
            '     document: ${row.files.document}, documents: ${row.files.documents}',
          );
          print(
            '     multimedia: ${row.files.multimedia}, multimediaFiles: ${row.files.multimediaFiles}',
          );
        }
      }

      await _mongoService.updateCatalogFromObject(updatedCatalog);
      print('✅ Catálogo guardado correctamente');
      // Notificar a los listeners después de guardar
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al guardar cambios: $e';
      print('❌ Error guardando catálogo: $e');
      notifyListeners();
    }
  }
}
