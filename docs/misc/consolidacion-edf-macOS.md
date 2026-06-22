# Plan de comparación y consolidación
## `edf_catalogotablas_macOS` → `EDFCatalogoMultiplatform`

> **Objetivo:** Identificar qué funcionalidad del monorepo .NET vale portar a Flutter, implementarla, y dejar `edf_catalogotablas_macOS` listo para eliminación segura.

---

## 1. Inventario: qué tiene el Blazor y en qué estado está en Flutter

| Funcionalidad | Blazor (`edf_catalogotablas_macOS`) | Flutter (`EDFCatalogoMultiplatform`) | Decisión |
|---|---|---|---|
| CRUD catálogos | `CatalogServiceMongo.cs` + `CatalogController.cs` | `mongo_service.dart` (completo) | ✅ Ya cubierto |
| CRUD usuarios | `UserService.cs` + `UserController.cs` | `mongo_service.dart` + `admin_users_list_view.dart` | ✅ Ya cubierto |
| Autenticación | `AuthServiceMongo.cs` | `auth_viewmodel.dart` + `KeychainService` | ✅ Ya cubierto |
| Gestión de roles | `EditRoleModal.razor` + `UpdateUserRoleAsync` | `admin_user_detail_view.dart` | ✅ Ya cubierto |
| Reset de contraseña | `ResetPasswordAsync` + token por email | `mongo_service.dart` → `savePasswordResetToken` | ✅ Ya cubierto |
| Registro de usuario | `Register.razor` | `register_view.dart` | ✅ Ya cubierto |
| Lista admin de usuarios | `UserManagement.razor` | `admin_users_list_view.dart` | ✅ Ya cubierto |
| Catálogos por usuario (admin) | `CatalogList.razor` (filtrado por userEmail) | `admin_user_catalogs_view.dart` | ✅ Ya cubierto |
| Export CSV / Excel | — (Blazor no tiene export) | `export_service.dart` | ✅ Flutter lo supera |
| Subida / previsualización de archivos | `UploadFileComponent.razor` + `FileService.cs` (almacenamiento local) | S3 (`s3_service.dart`) + `file_viewer_view.dart` | ✅ Flutter usa S3 (mejor) |
| Visor multimedia (audio/vídeo/PDF) | `MultimediaPreview.razor` + `FileViewerModal.razor` | `file_viewer_view.dart` (completo con reproductor inline) | ✅ Ya cubierto |
| Docker Web | — | `docs/linux/`, `Dockerfile` | ✅ Ya cubierto |
| Deduplicación de catálogos | — | `scripts/cleanup_duplicate_catalogs.dart` | ✅ Solo en Flutter |
| **Vaciado de colección (CleanCatalogs)** | `CleanCatalogs/Program.cs` (.NET CLI) | ❌ No existe | ⚙️ **Portar a Dart** |
| **Estadísticas de usuarios** | `GetUserStatsAsync()` | ❌ No existe en MongoService | ⚙️ **Portar** (bajo esfuerzo) |
| **Formulario de contacto** | `Contact.razor` (guarda en colección `contacts`) | ❌ No existe | 🔵 Opcional |
| **Tests E2E** | `EDFCatalogoTablasNet.E2E/` (Playwright, 6 tests) | ❌ No existe | 🔵 Opcional (alto esfuerzo) |
| **Seeder de datos de prueba** | `DatabaseSeeder.cs` | ❌ No existe | ⚙️ **Portar a Dart** |
| `MongoUserBsonHelper` (PascalCase/camelCase) | Util separado | Inline en `mongo_service.dart` (`doc['Email'] ?? doc['email']`) | ✅ Ya cubierto (distinto estilo) |
| Health API (`/health`) | `HealthApiTests` → endpoint ASP.NET | ❌ No existe en Flutter Web | 🔵 Opcional |
| Blazor circuit / session handling | `AuthCircuitHandler.cs`, `CircuitIdService.cs` | N/A (no aplica a Flutter) | 🚫 No migrar |
| REST API controllers | `CatalogController.cs`, `UserController.cs` | N/A (Flutter accede directo a MongoDB) | 🚫 No migrar |
| Scripts Homebrew / macOS setup | `scripts/brew-*.sh`, `Brewfile` | N/A | 🚫 No migrar |

---

## 2. Tareas a implementar (ordenadas por prioridad)

### P1 — Alta prioridad, bajo esfuerzo

#### T1 · Portar CleanCatalogs a Dart
`edf_catalogotablas_macOS/CleanCatalogs/Program.cs` → `scripts/clean_catalogs.dart`

El script C# tiene ~80 líneas útiles. La versión Dart equivalente es trivial con el paquete `mongo_dart` ya disponible.

```
Salida del script:
  🔌 Conectando a MongoDB...
  📊 Documentos en 'catalogs': 142
  🗑️  Eliminando todos los documentos...
  ✅ Eliminados: 142
  📊 Documentos restantes: 0
```

Variables de entorno: `MONGO_URI` (obligatoria), `MONGO_DB` (por defecto: `edf_catalogotablas`), `MONGO_CATALOGS_COLLECTION` (por defecto: `catalogs`).

Argumentos: `--dry-run` (solo muestra recuento), `--help`.

**Resultado:** se elimina la única dependencia .NET de uso operativo.

---

#### T2 · DatabaseSeeder → `scripts/seed_test_data.dart`
`EDFCatalogoTablasNet/Services/DatabaseSeeder.cs` → `scripts/seed_test_data.dart`

El seeder crea un usuario admin con contraseña hasheada si no existe. Útil para CI y entornos de prueba.

Comportamiento:
- Comprueba si ya existe `admin@edf.com`.
- Si no existe, lo crea con hash bcrypt de la contraseña de `ADMIN_PASSWORD` (var de entorno).
- Crea 2-3 catálogos de ejemplo con filas.
- Salida en consola: `✅ Seeded: 1 admin, 3 catálogos, 12 filas`.

---

#### T3 · `getUserStats()` en `mongo_service.dart`
`UserService.GetUserStatsAsync()` → nuevo método en `lib/services/mongo_service.dart`

```dart
Future<Map<String, int>> getUserStats() async {
  // Total, activos, inactivos, por rol (admin / user)
}
```

Útil para el panel admin (`admin_panel_view.dart`). El Blazor lo tiene pero Flutter no lo expone.

---

### P2 — Media prioridad

#### T4 · Formulario de contacto (opcional)
`Contact.razor` → nueva pantalla `lib/views/screens/contact_view.dart`

El Blazor guarda mensajes en colección `contacts` (campos: nombre, email, mensaje, fecha). Útil si se añade un canal de soporte. Requiere:
- Nueva pantalla `ContactView`
- Método `saveContactMessage(...)` en `mongo_service.dart`
- Entrada en el menú / navegación

---

#### T5 · Integration tests básicos (opcional)
`EDFCatalogoTablasNet.E2E/` → `integration_test/` en Flutter

Los E2E del Blazor cubren:
1. Login correcto / incorrecto
2. Acceso sin login → mensaje restringido
3. Crear catálogo → verificar en lista
4. Ciclo completo: crear catálogo → añadir fila → exportar → editar fila → editar catálogo → eliminar fila
5. Gestión de usuarios admin

En Flutter esto se implementa con `flutter_test` + `integration_test`. Requiere device/emulator en CI.

---

## 3. Lo que NO migrar y por qué

| Componente | Motivo |
|---|---|
| Blazor UI (`.razor`) | Flutter ya tiene UI equivalente o superior |
| `AuthCircuitHandler`, `CircuitIdService` | Exclusivos de Blazor Server (WebSockets de Signalr) |
| REST API controllers | Flutter usa MongoDB directamente; capa API no necesaria |
| `FileService.cs` (upload local) | Flutter usa S3; almacenamiento local sería regresión |
| `MongoUserBsonHelper` | La lógica ya está inline en `mongo_service.dart` |
| `Brewfile`, `scripts/brew-*.sh` | Herramientas de entorno macOS del desarrollador, no del proyecto |
| `AuthServiceMongo.cs` / `IAuthService` | Patrón de Blazor, sin equivalente en MVVM Flutter |
| `EDFCatalogoSwift/` (dentro del monorepo) | Copia incompleta; el original está en `../EDFCatalogoSwift/` |

---

## 4. Criterio de eliminación de `edf_catalogotablas_macOS`

El directorio puede eliminarse con seguridad **cuando se complete**:

- [ ] **T1** — `scripts/clean_catalogs.dart` implementado y documentado
- [ ] **T2** — `scripts/seed_test_data.dart` implementado
- [ ] **T3** — `getUserStats()` en `mongo_service.dart`
- [ ] Verificación: CI pasa con los nuevos scripts
- [ ] Commit final con mensaje: `chore: consolidar edf_catalogotablas_macOS en Multiplatform (T1/T2/T3)`

T4 y T5 son opcionales y no bloquean la eliminación.

---

## 5. Orden de ejecución recomendado

```
Semana 1
  T1 · clean_catalogs.dart     (~2h)  → elimina dependencia .NET operativa
  T2 · seed_test_data.dart     (~2h)  → mejora DX en entornos de prueba
  T3 · getUserStats()          (~1h)  → mejora panel admin

Semana 2 (opcional)
  T4 · contact_view.dart       (~3h)
  T5 · integration_test/       (~6h)

Al completar T1+T2+T3 → eliminar edf_catalogotablas_macOS
```

---

## 6. Impacto en espacio en disco

| Directorio | Tamaño | Estado tras consolidación |
|---|---|---|
| `edf_catalogotablas_macOS/` | ~800 MB | 🗑️ Eliminar (al completar T1+T2+T3) |
| `EDFCatalogoTablasNet/` (raíz) | 688 MB | 🗑️ Eliminar ahora (duplicado de la copia en monorepo) |
| `edf_catalogotablas_macOS/EDFCatalogoSwift/` | ~1.1 GB | 🗑️ Eliminar ahora (copia incompleta; original en `../EDFCatalogoSwift/`) |
| `EDFCatalogoSwift/` (raíz) | 4.6 GB | Conservar (repo git archivado en GitHub) |
| `PLAN_CONSOLIDACION.md` | < 1 MB | 🗑️ Eliminar (completado) |

**Ahorro inmediato** (sin implementar nada): ~1.8 GB (`EDFCatalogoTablasNet` raíz + `EDFCatalogoSwift` interno).  
**Ahorro total** (tras T1+T2+T3): ~2.6 GB.

---

*Documento generado: 2026-06-21*  
*Repositorio de referencia: `EDFCatalogoMultiplatform` (`edfrutos/EDFCatalogoMultiplatform`)*
