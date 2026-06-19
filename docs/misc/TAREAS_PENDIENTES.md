# Tareas Pendientes

## Backups

### Tamaño de archivos de backup
- **Problema**: El tamaño de los archivos de backup no se muestra correctamente (aparece como 0)
- **Ubicación**: `lib/services/google_drive_backup_service.dart` - Métodos `listCatalogBackups()`, `listUserBackups()`, `listProjectBackups()`
- **Estado**: Pendiente
- **Notas**: 
  - Se intentó obtener el tamaño mediante llamadas adicionales a `files.get()` si no está disponible en el listado
  - La API de Google Drive puede no devolver el tamaño en el listado inicial
  - Requiere investigación adicional sobre la obtención correcta del tamaño desde Google Drive API

