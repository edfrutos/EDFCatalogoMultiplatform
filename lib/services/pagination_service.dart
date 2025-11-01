/// Servicio de utilidades para paginación
class PaginationService {
  /// Calcula el número total de páginas basado en items totales e items por página
  static int calculateTotalPages(int totalItems, int itemsPerPage) {
    if (itemsPerPage <= 0) return 1;
    return (totalItems / itemsPerPage).ceil();
  }

  /// Obtiene los items de una página específica
  static List<T> getPageItems<T>(List<T> allItems, int currentPage, int itemsPerPage) {
    if (allItems.isEmpty || itemsPerPage <= 0) {
      return [];
    }

    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= allItems.length) {
      return [];
    }

    final actualEndIndex = endIndex > allItems.length ? allItems.length : endIndex;
    return allItems.sublist(startIndex, actualEndIndex);
  }

  /// Verifica si hay una página siguiente
  static bool hasNextPage(int currentPage, int totalPages) {
    return currentPage < totalPages;
  }

  /// Verifica si hay una página anterior
  static bool hasPreviousPage(int currentPage) {
    return currentPage > 1;
  }

  /// Obtiene el rango de items mostrados (ej: "1-20 de 150")
  static String getItemsRange(int currentPage, int itemsPerPage, int totalItems) {
    if (totalItems == 0) return '0 resultados';
    
    final startIndex = (currentPage - 1) * itemsPerPage + 1;
    final endIndex = (startIndex + itemsPerPage - 1) > totalItems 
        ? totalItems 
        : (startIndex + itemsPerPage - 1);
    
    return '$startIndex-$endIndex de $totalItems';
  }
}

