import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/catalog.dart';

/// Servicio para exportar catálogos a diferentes formatos
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  static ExportService get shared => _instance;
  ExportService._internal();

  /// Exporta un catálogo a CSV
  /// Retorna la ruta del archivo creado
  Future<String> exportToCsv(Catalog catalog) async {
    final List<List<dynamic>> rows = [];

    // Encabezado
    final header = List<String>.from(catalog.columns);
    rows.add(header);

    // Filas de datos
    for (final row in catalog.rows) {
      final rowData = <String>[];
      for (final column in catalog.columns) {
        rowData.add(row.data[column] ?? '');
      }
      rows.add(rowData);
    }

    // Convertir a CSV
    final csvString = const ListToCsvConverter().convert(rows);

    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${_sanitizeFileName(catalog.name)}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);

    return file.path;
  }

  /// Exporta un catálogo a Excel (XLSX)
  /// Retorna la ruta del archivo creado
  Future<String> exportToExcel(Catalog catalog) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1'); // Eliminar hoja por defecto
    final sheet = excel[_sanitizeFileName(catalog.name)];

    // Encabezado
    for (int i = 0; i < catalog.columns.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = catalog.columns[i];
      // Estilo para encabezado
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#E8E8E8',
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Filas de datos
    for (int rowIndex = 0; rowIndex < catalog.rows.length; rowIndex++) {
      final row = catalog.rows[rowIndex];
      for (int colIndex = 0; colIndex < catalog.columns.length; colIndex++) {
        final column = catalog.columns[colIndex];
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          ),
        );
        cell.value = row.data[column] ?? '';
      }
    }

    // Ajustar ancho de columnas
    for (int i = 0; i < catalog.columns.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }

    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${_sanitizeFileName(catalog.name)}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${directory.path}/$fileName');
    final excelBytes = excel.save();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
    }

    return file.path;
  }

  /// Exporta múltiples catálogos a un único archivo Excel con múltiples hojas
  Future<String> exportCatalogsToExcel(List<Catalog> catalogs) async {
    if (catalogs.isEmpty) {
      throw Exception('No hay catálogos para exportar');
    }

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    for (final catalog in catalogs) {
      final sheetName = _sanitizeSheetName(catalog.name);
      final sheet = excel[sheetName];

      // Encabezado
      for (int i = 0; i < catalog.columns.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = catalog.columns[i];
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#E8E8E8',
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Filas de datos
      for (int rowIndex = 0; rowIndex < catalog.rows.length; rowIndex++) {
        final row = catalog.rows[rowIndex];
        for (int colIndex = 0; colIndex < catalog.columns.length; colIndex++) {
          final column = catalog.columns[colIndex];
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1,
            ),
          );
          cell.value = row.data[column] ?? '';
        }
      }

      // Ajustar ancho de columnas
      for (int i = 0; i < catalog.columns.length; i++) {
        sheet.setColumnWidth(i, 20.0);
      }
    }

    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'Catalogs_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${directory.path}/$fileName');
    final excelBytes = excel.save();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
    }

    return file.path;
  }

  /// Comparte un archivo exportado
  Future<void> shareFile(String filePath, String fileName) async {
    final file = XFile(filePath);
    await Share.shareXFiles(
      [file],
      text: 'Exportación: $fileName',
      subject: fileName,
    );
  }

  /// Exporta y comparte un catálogo como CSV
  Future<void> exportAndShareCsv(Catalog catalog) async {
    try {
      final filePath = await exportToCsv(catalog);
      final fileName = '${_sanitizeFileName(catalog.name)}.csv';
      await shareFile(filePath, fileName);
    } catch (e) {
      throw Exception('Error al exportar CSV: $e');
    }
  }

  /// Exporta y comparte un catálogo como Excel
  Future<void> exportAndShareExcel(Catalog catalog) async {
    try {
      final filePath = await exportToExcel(catalog);
      final fileName = '${_sanitizeFileName(catalog.name)}.xlsx';
      await shareFile(filePath, fileName);
    } catch (e) {
      throw Exception('Error al exportar Excel: $e');
    }
  }

  /// Sanitiza el nombre del archivo para que sea válido
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .substring(0, name.length > 50 ? 50 : name.length);
  }

  /// Sanitiza el nombre de la hoja de Excel (máximo 31 caracteres)
  String _sanitizeSheetName(String name) {
    var sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\[\]]'), '_')
        .replaceAll(' ', '_');

    if (sanitized.length > 31) {
      sanitized = sanitized.substring(0, 31);
    }

    return sanitized.isEmpty ? 'Sheet1' : sanitized;
  }
}
