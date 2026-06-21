# cleanup_duplicate_catalogs — Script CLI

Script Dart para detectar y eliminar catálogos duplicados en MongoDB.
Se ejecuta directamente con `dart run` desde la raíz del proyecto; no requiere compilación previa.

## Ubicación

```
scripts/cleanup_duplicate_catalogs.dart
```

## Requisitos

- Dart SDK instalado (incluido con Flutter)
- Archivo `.env` en la raíz del proyecto con `MONGO_URI` y `MONGO_DB`
- Dependencia `mongo_dart` declarada en `pubspec.yaml`

## Uso

```bash
# Desde la raíz del proyecto (recomendado)
dart run scripts/cleanup_duplicate_catalogs.dart
```

El script busca el archivo `.env` en varias rutas relativas partiendo del
directorio de trabajo actual. Si se ejecuta desde otro directorio, puede que
no lo encuentre; añade `--define=ENV_PATH=/ruta/a/.env` como alternativa
o sitúate en la raíz del proyecto.

## Qué hace

1. **Carga `.env`** — Lee `MONGO_URI` y `MONGO_DB`. Soporta URIs con y sin
   parámetros de consulta (`?retryWrites=true&w=majority`).

2. **Conecta a MongoDB** — Construye la URI de conexión con el nombre de BD
   correcto y abre la conexión. Si la BD conectada no coincide con `MONGO_DB`,
   reintenta con la URI corregida.

3. **Lee todos los catálogos** — Descarga la colección `catalogs` completa.

4. **Agrupa por (nombre, propietario)** — Normaliza el nombre a minúsculas y
   busca el propietario en los campos `Owner`, `CreatedBy`, `userId` o `UserId`.
   Cada combinación única `nombre|propietario` forma un grupo.

5. **Detecta duplicados** — Grupos con más de un documento se consideran
   duplicados.

6. **Selecciona el documento canónico** — Dentro de cada grupo de duplicados,
   elige el documento con más entradas en `FileTitles` (el más completo).

7. **Elimina los duplicados** — Borra del grupo todos los documentos que no
   son el canónico.

8. **Imprime resumen** — Muestra cuántos grupos duplicados había, cuántos
   documentos se eliminaron y si hubo errores.

## Variables de entorno necesarias

| Variable   | Descripción                                    | Ejemplo                                  |
|------------|------------------------------------------------|------------------------------------------|
| `MONGO_URI`| URI de conexión a MongoDB Atlas                | `mongodb+srv://user:pass@cluster/`       |
| `MONGO_DB` | Nombre de la base de datos                     | `edf_catalogo`                           |

## Salida esperada

```
🔍 Iniciando limpieza de catálogos duplicados...

✅ Archivo .env cargado desde: .env
🔗 URI de conexión: mongodb+srv://***@cluster/edf_catalogo
✅ Conectado a MongoDB: edf_catalogo

📊 Total de catálogos encontrados: 247
📊 Grupos de catálogos encontrados: 231

🔍 Duplicados encontrados para: "Catálogo Primavera 2024" (2 registros)
  ✅ Manteniendo: <id> (3 FileTitles)
  🗑️  Eliminando: <id> (1 FileTitles)

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Limpieza completada
   Grupos con duplicados : 16
   Documentos eliminados : 19
   Errores               : 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Precauciones

- **Ejecuta primero en una base de datos de prueba** o con un backup reciente.
  El script elimina documentos de forma permanente (no hay papelera).
- La selección del documento canónico se basa en el recuento de `FileTitles`.
  Si dos duplicados tienen el mismo recuento, se conserva el primero que
  aparece en el cursor de MongoDB (orden de inserción).
- El script es idempotente: ejecutarlo varias veces produce el mismo resultado
  si no hay nuevos duplicados.

## Cuándo ejecutarlo

- Tras una migración o importación masiva de datos.
- Si la aplicación mostró catálogos duplicados visibles en la UI.
- Como tarea de mantenimiento periódico si se sospecha de inserciones dobles.
