# edfcat.efjdefrutos.com — Documentación de infraestructura

**Servidor:** `edf-familiaonline` (Vultr, Madrid — Plesk Obsidian sobre Ubuntu 20.04)
**Última revisión:** 6 de septiembre de 2026

---

## 1. Arquitectura general

Aplicación de catálogo (`edfcatalogomultiplatform`) compuesta por:

- **Frontend**: SPA Flutter (compilado a web), servido de forma estática por nginx.
- **Backend**: API propia escrita en **Dart** (`package:shelf`), ejecutándose en un **contenedor Docker**.
- **Base de datos**: MongoDB Atlas (cluster remoto, no local).
- **Almacenamiento de ficheros**: Amazon S3.

Es una aplicación **independiente** de `catalogotablas.edefrutos2020.com` (que usa `catalogotablas.service` en el puerto 5100), aunque ambas conviven en el mismo servidor `edf-familiaonline`.

---

## 2. Ubicación en el servidor

| Elemento | Ruta / valor |
|---|---|
| Código y configuración del proyecto | `/opt/edfcatalogo/` |
| Docker Compose (web) | `/opt/edfcatalogo/docker/docker-compose.web.yml` |
| Docker Compose (producción) | `/opt/edfcatalogo/docker/docker-compose.prod.yml` |
| Variables de entorno | `/opt/edfcatalogo/.env` (también existen `.env.example`, y en `/root/`: `edfcat.env.empty`, `edfcat.env.private`) |
| Document root Plesk (frontend) | `/var/www/vhosts/efjdefrutos.com/edfcat.efjdefrutos.com/` |
| Panel Plesk | Domain ID 106, subscripción "EDF Dominios" |

> **Importante**: el contenedor Docker de la API **no vive bajo `/var/www/vhosts/...`**, sino en `/opt/edfcatalogo/`. La carpeta de Plesk solo contiene los assets estáticos del frontend Flutter.

---

## 3. Contenedor Docker

| Campo | Valor |
|---|---|
| Nombre del contenedor | `edfcatalogo-api-prod` |
| Imagen | `edfcatalogo-api:latest` |
| Comando de arranque | `/app/bin/server` |
| Puerto expuesto | `127.0.0.1:8089 -> 8089/tcp` (solo loopback, no accesible desde fuera directamente) |
| Proyecto Compose | `docker` (label `com.docker.compose.project=docker`, `com.docker.compose.service=api`) |
| Shell disponible | **No** — imagen mínima, sin `sh` ni `bash` (Dart AOT compilado) |

### Comandos habituales

```bash
# Estado
docker ps | grep edfcatalogo-api-prod

# Logs
docker logs --tail 100 edfcatalogo-api-prod
docker logs -f edfcatalogo-api-prod

# Reinicio
docker restart edfcatalogo-api-prod

# Copiar el binario para inspección (no hay shell dentro)
docker cp edfcatalogo-api-prod:/app/bin/server /tmp/edfcat-server
strings /tmp/edfcat-server | grep -E "^/[a-zA-Z0-9_{/-]+$" | sort -u
```

**Nota sobre el reinicio**: el backend consulta MongoDB Atlas y S3 en cada petición, sin caché intermedia. Reiniciar el contenedor **no es necesario** tras actualizar datos en BD o S3 — los cambios se reflejan de inmediato. Solo tiene sentido reiniciarlo por mantenimiento rutinario o si se detecta comportamiento anómalo.

---

## 4. Proxy inverso (nginx, config Plesk)

Configurado en el panel Plesk → dominio → **Directivas adicionales de nginx**:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}

location /api/ {
    proxy_pass http://127.0.0.1:8089;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

- Todo lo que no sea `/api/...` cae al `index.html` del SPA Flutter (por eso `/health` público devuelve el HTML del frontend, no la respuesta del backend).
- Solo las rutas bajo `/api/` llegan al contenedor.

---

## 5. Base de datos (MongoDB Atlas)

| Campo | Valor |
|---|---|
| Cluster | `cluster0.alh9mwn.mongodb.net` |
| Base de datos | `edf_catalogotablas` |
| Variable de entorno | `MONGO_URI` (en `/opt/edfcatalogo/.env`) |
| Colección relevante | `catalogs` (documentos identificados por `_id` ObjectId) |

### Consulta segura (sin exponer credenciales)

```bash
# Ver el host sin mostrar usuario/contraseña
grep -i "mongo" /opt/edfcatalogo/.env | sed -E 's/(:\/\/)[^:]+:[^@]+@/\1***:***@/'

# Cargar la URI en variable de entorno sin pegarla en el historial
export MONGO_URI=$(grep -oP '(?<=MONGO_URI=).*' /opt/edfcatalogo/.env)

mongosh "$MONGO_URI" --quiet --eval 'db.getCollectionNames()'
mongosh "$MONGO_URI" --quiet --eval 'db.catalogs.findOne({}, {_id: 1, UpdatedAt: 1})'
```

`mongosh` no viene preinstalado en este servidor (no hay contenedor Mongo local); se instaló el cliente vía repositorio oficial de MongoDB para Ubuntu 20.04 (focal).

---

## 6. Almacenamiento S3

- Bucket: `edfcatalogotablas-sp` (región `eu-south-2`)
- Estructura de rutas: `users/<user_id>/catalogs/<catalog_id>/{image,document}/<uuid>.<ext>`
- El backend expone un endpoint de *presigned URLs* para subida/descarga directa cliente↔S3 (ver rutas más abajo).

---

## 7. Rutas de la API identificadas

Extraídas mediante `strings` sobre el binario Dart compilado (`/app/bin/server`). No hay documentación tipo Swagger/OpenAPI disponible; esta lista es la mejor aproximación conocida.

| Grupo | Ruta | Notas |
|---|---|---|
| Auth | `POST /api/auth/login` | Body: `{"emailOrUsername": "...", "password": "..."}`. Devuelve `{"user": {...}, "token": "<JWT>"}` |
| Auth | `POST /api/auth/refresh` | Renovación de token (sin verificar parámetros exactos aún) |
| Users | `/api/users/check-exists` | — |
| Users | `/api/users/password`, `/password/reset-token`, `/password/token`, `/password/verify-token` | Flujo de recuperación de contraseña |
| Catalogs | `GET /api/catalogs/<ObjectId de 24 hex>` | Requiere `Authorization: Bearer <token>`. Devuelve el catálogo completo (Headers, Rows, Files, S3 URLs) |
| Catalogs | `/api/catalogs/upload`, `/delete` | — |
| S3 | `/api/s3/presign` | Generación de URLs firmadas |
| Contact | `/api/contact/` | — |

**Confirmado que NO existe**: `GET /api/catalogs` (listado general) — devuelve `{"error":"Ruta no encontrada"}`. Solo se accede por ID concreto.

**Nota sobre `/stats`**: aparece como cadena en el binario pero no se ha localizado su ruta real; no cuelga de `/api/catalogs/` ni de `/api/`.

### Ejemplo de verificación end-to-end

```bash
# 1. Login
curl -s -X POST https://edfcat.efjdefrutos.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emailOrUsername":"edefrutos","password":"***"}' \
  | grep -o '"token":"[^"]*"'

# 2. Consultar un catálogo concreto
TOKEN="<pegar_token>"
curl -s https://edfcat.efjdefrutos.com/api/catalogs/<ID_CATALOGO> \
  -H "Authorization: Bearer $TOKEN"
```

---

## 8. Notas de seguridad

- El JWT y el hash de contraseña (`scrypt:...`) **no deben pegarse completos en logs, tickets o chats** — usar `grep -o`/`sed` para extraer solo lo necesario y enmascarar el resto.
- La URI de Mongo Atlas contiene credenciales embebidas: tratar `/opt/edfcatalogo/.env` como fichero sensible (permisos restringidos, no versionarlo en git si no lo está ya).
- El puerto 8089 del contenedor solo escucha en `127.0.0.1` (no expuesto directamente a internet); el único punto de entrada público es nginx vía `/api/`.

---

## 9. Auditoría S3 (6 de septiembre de 2026)

### Resultado: infraestructura sana, bug de sincronización en el cliente

Se subieron ficheros de prueba (imagen, PDF, vídeo) desde la app a un catálogo de prueba (`6a9d46dd46b107bdfa473503`, usuario `68f7b5028edeaa47ec4fcd45`) y se verificó tanto en los logs del contenedor como directamente en S3 (vía AWS CLI, sin pasar por la API):

```bash
aws s3api head-object --bucket edfcatalogotablas-sp --key "<key>"
aws s3 ls "s3://edfcatalogotablas-sp/users/<user_id>/catalogs/<catalog_id>/" --recursive
```

**Resultado — los 5 ficheros llegaron correctamente a S3** (cifrado `AES256`, `content-type` correcto en cada caso):

- 1 PDF (`document/`)
- 3 PNG (`image/`)
- 1 MP4 (`multimedia/`)

**Pero el documento del catálogo en MongoDB tenía `Images: []`, `Documents: []`, `MultimediaFiles: []` vacíos** — ninguna de las 5 subidas quedó referenciada en la fila (`Row`) correspondiente. Confirmado con `mongosh` directo, sin pasar por la API (para descartar problemas de autorización/caché).

**Conclusión**: el pipeline de subida a S3 (backend Dart + bucket) funciona correctamente de principio a fin — no hay errores de AWS, ni timeouts, ni fallos de permisos. El problema está en el **cliente Flutter**: el flujo de "subir fichero → guardar referencia en el estado local → `PUT /api/catalogs/<id>` para persistir" no está consolidando correctamente las referencias antes de guardar, o llamadas `PUT` sucesivas se pisan entre sí (se observaron 4 `PUT` casi seguidos sobre el mismo catálogo en el margen de un minuto).

### Causa raíz confirmada (revisión de código, mismo día)

**Condición de carrera por guardado sin serializar**, en `lib/viewmodels/catalog_detail_viewmodel.dart`:

- `addRow()` y `updateRow()` son funciones `void` que llaman a `_persistCatalogChanges()` **sin `await`** — el guardado se dispara en segundo plano sin esperar a que termine.
- `_persistCatalogChanges()` construye un snapshot del catálogo a partir de `_originalRows` en el instante de la llamada, y envía ese snapshot completo vía `PUT /api/catalogs/<id>` (`api/lib/routes/catalog_routes.dart`, `coll.updateOne(where.id(oid), {r'$set': updates})` con `updates['Rows'] = body['rows']` — reemplaza el array `Rows` completo, no una fila individual).
- Si se disparan varias llamadas `_persistCatalogChanges()` en poco tiempo (p. ej. varias filas/subidas seguidas), cada una lleva su propio snapshot tomado en un instante distinto. Al ser peticiones HTTP asíncronas, no hay garantía de que completen en el mismo orden en que se dispararon — si una petición con un snapshot **más antiguo** completa **después** que una con un snapshot más reciente, su `$set` de `Rows` sobrescribe silenciosamente los cambios más nuevos (incluida la fila con los ficheros recién subidos).

Esto coincide exactamente con lo observado: 4 llamadas `PUT` sobre el mismo catálogo en ~1 minuto durante las pruebas, resultando en una fila final sin ninguno de los 5 ficheros subidos.

**Corrección propuesta (pendiente de implementar, fuera del ámbito de servidor):**
1. Cliente — serializar los guardados: hacer `addRow`/`updateRow` `async` con `await _persistCatalogChanges()`, evitando disparar una nueva petición de guardado mientras la anterior sigue en curso.
2. Backend (más robusto, opcional) — cambiar el `PUT` para actualizar la fila concreta de forma atómica (`$set` con `arrayFilters` sobre el elemento del array `Rows`) en vez de reemplazar el array completo, eliminando la ventana de carrera por diseño.

**Aún sin confirmar**: no se encontró ninguna subida de `.txt`/`.md` en los logs del backend durante las pruebas — pendiente de repetir la prueba ahora que la causa raíz del resto está identificada (podría no ser un problema aparte, sino la misma condición de carrera).

### Corrección aplicada y verificada (6 de septiembre de 2026)

**Commits:**
- `4f145fe` — `fix(catalog): serializar guardados de filas para evitar condición de carrera que perdía ficheros S3`. Añade `_saveQueue` (un `Future` encadenado) en `CatalogDetailViewModel`; `_persistCatalogChanges()` ahora encola la ejecución real (renombrada `_persistCatalogChangesNow()`) en vez de dispararla directamente, garantizando que los guardados se ejecuten estrictamente en el orden en que se llamaron, sin inversión posible.
- `72b51b3` — `test(catalog): añadir inyección de MongoService y test de la cola de guardado`. Se añadió inyección opcional de `MongoService` por constructor (`MongoService? mongoService`, por defecto `MongoService.shared` — sin impacto en el resto de instanciaciones existentes) para permitir testear con mocks (`mocktail`, ya usado en el proyecto). Nuevo test en `test/viewmodels/catalog_detail_viewmodel_test.dart`: dispara dos `addRow()` casi simultáneos con un mock cuya respuesta al primero se demora más que al segundo (invirtiendo el orden de llegada, reproduciendo el bug original) — **test en verde**, confirma que ambas filas quedan en el catálogo final tras el fix.

**Desplegado a producción** vía `./scripts/deploy.sh` tras el commit `4f145fe` (el commit de test, `72b51b3`, no requiere redeploy — solo añade tests, no cambia el build).

Afecta a **todas las plataformas** (macOS, Linux, Windows, Android, iOS, Web) por igual — el código corregido es Dart compartido del `ViewModel`, sin ramas específicas por plataforma en esta parte.

### Verificación en producción (7 de septiembre de 2026)

Se repitió la prueba original directamente en producción: catálogo nuevo ("Prueba 1", `6a9e747d46b107bdfa473504`), con una tanda de **9 subidas casi simultáneas** (imágenes, documento, vídeos) entre las 08:27:55 y las 08:27:59 — el escenario exacto que antes disparaba la condición de carrera.

**Resultado: todos los ficheros quedaron correctamente consolidados en una única fila** — 4 imágenes (`Image` + `Images[3]`), 1 documento, 4 vídeos (`Multimedia` + `MultimediaFiles[3]`). Confirmado por consulta directa a MongoDB, sin pérdidas.

Nota de proceso: durante la verificación hubo confusión inicial porque se consultó por error el catálogo de la prueba del día anterior (ID distinto) en vez del nuevo — al revisar el catálogo correcto, el resultado fue limpio. La sensación de "los datos desaparecen y reaparecen al cerrar/reabrir sesión" reportada durante la prueba se debió a la lista de catálogos no estar mirando el catálogo recién creado, no a una pérdida real de datos — el guardado en MongoDB fue correcto en todo momento según los logs y la consulta final.

**Diagnóstico y corrección cerrados.**

## 13. Bug 2 — Miniatura de catálogo (`ThumbnailUrl`) nunca se guardaba

**Síntoma reportado (7 de septiembre de 2026):** al subir una foto de portada a un catálogo desde la pantalla de edición, guardar mostraba la imagen correctamente, pero al navegar fuera y volver (o recargar), la miniatura desaparecía.

**Causa raíz — desajuste de nombre de campo entre cliente y backend** (nada que ver con la condición de carrera del Bug 1):

- El backend (`PUT /api/catalogs/<id>`, `api/lib/routes/catalog_routes.dart`) solo reconoce el campo `ThumbnailUrl` para la miniatura.
- El cliente Flutter enviaba el campo como `'Miniatura'` en dos sitios: `lib/services/mongo_service.dart` (rama nativa, no usada en web) y `lib/models/catalog.dart` → `Catalog.toJson()` (rama web, la que realmente se usaba en las pruebas). El backend, al no reconocer `'Miniatura'`, lo ignoraba silenciosamente — el `PUT` devolvía `200 OK` (el resto de campos sí se actualizaban) pero `ThumbnailUrl` quedaba siempre vacío en MongoDB.
- Además, `Catalog.fromJson()` (lectura) tampoco contemplaba `'ThumbnailUrl'` entre los alias reconocidos (`Miniatura`, `Thumbnail`, `thumbnailUrl`), así que aunque el backend hubiera guardado el campo correctamente, el cliente tampoco lo habría leído de vuelta.

**Commit:** `03b3b82` — `fix(catalog): usar ThumbnailUrl en vez de Miniatura al leer/escribir la miniatura del catálogo`. Corrige `toJson()` para escribir `'ThumbnailUrl'`, añade `'ThumbnailUrl'` como alias de mayor prioridad en `fromJson()` (manteniendo compatibilidad con datos antiguos guardados bajo `Miniatura`/`Thumbnail`), y aplica el mismo fix en `mongo_service.dart` (rama nativa) por consistencia, aunque esa rama no se ejecuta en web.

**Verificación:** tras el despliegue, la primera comprobación en el navegador normal siguió fallando (`ThumbnailUrl` vacío pese al `PUT 200`) — **causa: el Service Worker de Flutter Web sirviendo el `main.dart.js` antiguo desde caché del navegador**, no un fallo del parche (el build en el servidor ya tenía el commit correcto, confirmado por timestamp). Repetida la prueba en ventana de incógnito (sin Service Worker previo): **`ThumbnailUrl` se guardó correctamente**. Confirmado en verde.

**Nota de proceso para futuras verificaciones de frontend:** después de cada despliegue, verificar en ventana de incógnito o tras hacer `Unregister` del Service Worker en DevTools (Application → Service Workers) — el navegador normal puede seguir sirviendo JS de un build anterior indefinidamente sin recarga forzada.

**Pendiente (mejora de infraestructura, no bug):** considerar deshabilitar el Service Worker en el build (`flutter build web --pwa-strategy=none`, ya marcado como deprecated por Flutter) o configurar cabeceras de caché cortas para `flutter_service_worker.js` en nginx/Plesk, para que los usuarios reales no se queden con builds antiguos tras cada despliegue.

## 14. Bug 3 — Miniatura de catálogo no se refrescaba en la UI sin recargar la página

**Síntoma reportado (7 de septiembre de 2026):** tras el fix del Bug 2 (miniatura ya persistiendo en Mongo correctamente), la miniatura seguía sin aparecer en la lista de catálogos al navegar a otra pantalla (p. ej. Perfil) y volver — solo aparecía tras recargar la página completa. Al navegar dentro del detalle de un catálogo y volver, sí refrescaba (con cierto retraso).

**Causa raíz:** `LazyImageWidget` (`lib/views/screens/widgets/lazy_image_widget.dart`), el `StatefulWidget` que usa la tarjeta de catálogo (`_CatalogCard` en `catalogs_view.dart`, vía `catalog.getDisplayImageUrl()`) para pre-firmar y cargar imágenes de S3, **no implementaba `didUpdateWidget`**. La URL pre-firmada (`_presignedUrl`) solo se calculaba una vez en `initState()`; si Flutter reutilizaba el mismo `State` en lugar de recrearlo al reconstruir la tarjeta con una `thumbnailUrl` nueva, el widget seguía mostrando la imagen (o el placeholder) de la carga inicial indefinidamente. Solo una recarga completa de página (que destruye y recrea todos los `State`) forzaba una nueva pre-firma.

A diferencia del widget hermano `S3PresignedBuilder` (mismo fichero de referencia, `s3_presigned_widget.dart`), que sí tenía `didUpdateWidget` correctamente implementado — de ahí que el avatar de perfil nunca mostrara este problema.

**Commit:** `fix(ui): LazyImageWidget no refrescaba la imagen al cambiar la URL sin recrear el widget`. Añade `didUpdateWidget`: si `widget.imageUrl` cambia respecto al build anterior, resetea `_presignedUrl` a `null` y vuelve a pre-firmar.

**Verificación:** la primera prueba tras el despliegue pareció inconsistente (a veces refrescaba, a veces no, según la ruta de navegación) — de nuevo por el Service Worker sirviendo JS mixto/antiguo en distintas rutas de caché, no por un fallo del fix. Repetida la prueba en incógnito limpio: la miniatura de cabecera y el contenido multimedia de las filas refrescan correctamente sin recargar la página (con un pequeño retraso perceptible, esperado por la llamada de presign).

**Pendiente de verificación menor:** confirmar el mismo comportamiento con **varios documentos** (`Document` + `Documents[]`) en una fila — ✅ verificado el 7 de septiembre de 2026 (ver Bug 4, sección 15): 2 documentos adicionales correctamente persistidos en `Documents[]` tras el fix del nombre de cabecera.

## 15. Bug 4 — Subida de fichero fallaba en silencio con nombres no-ISO-8859-1 (tildes/ñ)

**Síntoma reportado (7 de septiembre de 2026):** al subir varios ficheros a la vez (imagen, documento, vídeo) a una fila, la multimedia y algunas imágenes se guardaban bien, pero algunos documentos no — en concreto, los que tenían tildes en el nombre de archivo (`Guía de corte para encastrados.md`). Al editar y volver a intentar, el primer documento nuevo se guardaba pero los siguientes con nombres problemáticos seguían fallando.

**Causa raíz:** el cliente enviaba el nombre de archivo original tal cual en la cabecera HTTP `X-File-Name`. Las cabeceras HTTP solo admiten el juego de caracteres ISO-8859-1. Los nombres de archivo con tildes/ñ, especialmente en la forma de normalización **NFD** que usa macOS por defecto en su sistema de archivos (donde una "í" se representa como `i` + acento combinante `U+0301`, un carácter fuera de ISO-8859-1), hacían que la llamada `fetch()` del navegador fallara por completo antes de llegar al servidor: `ClientException: Failed to execute 'fetch' on 'Window': Failed to read the 'headers' property from 'RequestInit': String contains non ISO-8859-1 code point.` El error se registraba en consola pero no bloqueaba el resto del flujo de subida — de ahí que unos ficheros de la misma tanda se guardaran y otros no, según si su nombre tenía o no caracteres problemáticos.

**Commit:** `fix(s3): percent-encode X-File-Name para evitar fallo de fetch con nombres no-ISO-8859-1`. El cliente (`lib/services/api_service.dart`) codifica el nombre con `Uri.encodeComponent()` antes de meterlo en la cabecera; el backend (`api/lib/routes/s3_routes.dart`) lo decodifica con `Uri.decodeComponent()` al leerlo. Afecta a frontend y backend (mismo monorepo) — requirió rebuild del contenedor Docker de la API además del build de Flutter Web.

**Verificación:** tras el despliegue, se subieron varios documentos con tildes a una fila existente — confirmado en MongoDB: `documents (2): [...f6a1d70c....md, ...f5c19602....pdf]`, incluyendo el `.md` que antes fallaba sistemáticamente.

## 16. Hallazgos en curso (7 de septiembre de 2026, sesión abierta)

### 16.1 — Miniatura de catálogo con `thumbnailUrl` guardado bajo el userId equivocado (CERRADO)

**Síntoma:** al editar el thumbnail de un catálogo ajeno como admin (o subir ficheros a una fila de un catálogo ajeno), la key de S3 se construía usando el `userId` de quien editaba (el admin) en vez del dueño real del catálogo (`Owner`). El fichero se subía correctamente a S3, pero quedaba archivado bajo la carpeta del admin — y como `GET /api/s3/presign` valida propiedad del recurso, la miniatura nunca cargaba para nadie después: ni para el admin (no es su thumbnail, aunque esté en su carpeta) ni para el dueño real (la URL guardada apunta a una carpeta que no es la suya).

**Causa raíz confirmada:** en `edit_catalog_dialog.dart` y `add_edit_row_dialog.dart`, el cálculo de `userId` para construir la key de S3 priorizaba `AuthViewModel.currentUser?.id` (quien está editando) sobre el dueño real del catálogo.

**Commits:**
- `fix(s3): usar el userId del dueño del catálogo, no del editor, al construir keys de S3` (`c79ffe9`) — prioriza `widget.catalog.userId` (Owner real) sobre el usuario que edita, en ambos ficheros.

**Proceso de verificación (más largo de lo habitual):** varias rondas de debug prints instrumentando `_CatalogCard.build()` y el punto de subida de `edit_catalog_dialog.dart` para confirmar en vivo, en consola del navegador, qué `userId` se estaba usando realmente en cada capa (diálogo → `S3Service` → `ApiService` → cabecera `X-User-Id` → respuesta del backend). Se detectaron y descartaron varias falsas pistas por el camino:
- Una errata de tipeo (`widgt` en vez de `widget`) en un print de depuración causó confusión temporal sobre si el fix estaba desplegado.
- Salidas de terminal pegadas repetidas/obsoletas hicieron parecer que un fix no se había aplicado cuando sí lo estaba.
- Se confirmó, leyendo la respuesta JSON real de `POST /api/s3/upload` y consultando MongoDB directamente, que la key final (`users/68f7b5028edeaa47ec4fcd45/...`, userId de Julia) coincidía con el dueño real del catálogo — cierre confirmado con datos de producción, no solo por lectura de código.

Los dos debug prints usados durante el diagnóstico se revirtieron antes del cierre; `git diff` contra `HEAD` confirma que el árbol de trabajo no contiene código de depuración residual.

### 16.2 — Imágenes de alta resolución (cámara réflex/mirrorless) fallan al decodificar en Flutter Web (CERRADO — mitigado en cliente)

**Síntoma:** imágenes que se descargan correctamente desde S3 (`200 OK`, tamaño de respuesta correcto) fallan al decodificarse en el navegador: `LazyImageWidget: error cargando imagen: ImageCodecException: Failed to create image from Image.decode`. Confirmado tanto para el catálogo de Julia como, más tarde, para "Bricolaje" (catálogo del propio usuario admin) — no es específico de un catálogo ni de un usuario.

**Causa raíz identificada:** el fichero de prueba (`f370efff-...jpg`, subido desde una cámara Canon EOS M6, sin editar ni redimensionar) es un JPEG baseline válido (confirmado con `file`: `baseline, precision 8, 6000x4000, components 3`) — **no** es un problema de JPEG progresivo (hipótesis inicial, descartada) ni de fichero corrupto. La causa más probable es que **6000×4000 píxeles (24 megapíxeles) supera los límites de tamaño de textura del decodificador CanvasKit/Skia que usa Flutter Web**, un límite típico de hardware/navegador (a menudo 4096 u 8192 px de lado). El pipeline de subida actual no genera ninguna versión redimensionada — el fichero original a resolución completa es el que se sirve también para la miniatura en la lista y en la fila.

**Alcance:** no es un caso raro — cualquier foto sin editar de una cámara moderna (o de muchos móviles actuales, que ya disparan a 12-48 MP) puede reproducirlo.

**Solución recomendada (pendiente, cambio de mayor alcance):** generar una versión redimensionada (p. ej. 800-1200 px de lado mayor) en el backend al recibir la subida de una imagen, sirviendo esa versión para miniaturas y vistas en fila, y conservando el original solo para descarga bajo demanda. Requiere añadir una librería de procesamiento de imagen al backend Dart (`image` package u otra), tocar `api/lib/routes/s3_routes.dart`, y decidir si se generan ambas versiones o se sustituye el original.

**Mitigación insuficiente por sí sola:** limitar `memCacheWidth`/`memCacheHeight` en `LazyImageWidget` no evita el fallo, porque CanvasKit decodifica la imagen completa a resolución original antes de reescalarla — el fallo ocurre en la propia decodificación, no en el cacheo posterior.

**Corrección aplicada (mitigación en cliente, no redimensionado en backend):** en vez de procesar/redimensionar en el servidor (cambio de mayor alcance, descartado por ahora), se añadió una validación en el propio selector de ficheros del cliente web: `lib/utils/image_resolution_guard.dart` expone `checkWebImageResolution()`, que decodifica la imagen con `dart:ui.instantiateImageCodec` (el mismo decodificador de CanvasKit que fallaba) y rechaza cualquier imagen cuyo lado mayor supere `kMaxWebImageDimension` (4096 px, el límite típico de textura documentado arriba) — o que directamente no se pueda decodificar. Se aplica solo en `kIsWeb` (no restringe nativo, donde el decodificador de la plataforma no tiene este límite) en los dos puntos de subida de imágenes de catálogo: `add_edit_row_dialog.dart` (imágenes de fila) y `edit_catalog_dialog.dart` (miniatura de catálogo). El usuario ve un aviso (`_uploadError` / `SnackBar`) pidiéndole redimensionar la imagen antes de subirla, en vez de que el fallo aparezca más tarde, en silencio, al intentar visualizarla desde `LazyImageWidget`.

Fotos de móvil habituales (hasta ~4032×3024, 12 MP) quedan por debajo del límite y no se ven afectadas; solo se rechazan resoluciones propias de cámaras réflex/mirrorless sin redimensionar (ej. 6000×4000, 24 MP).

**Pendiente futuro (fuera de alcance de este cierre):** si se quiere aceptar también esas resoluciones altas, la solución de fondo sigue siendo redimensionar en el backend al subir (ver arriba) — no descartado, solo pospuesto.

### Próximos pasos (fuera del ámbito de servidor/infraestructura)

- Revisar en el repositorio Flutter la función que gestiona subida + guardado de ficheros por fila (buscar algo como `_onFileUploaded`, `saveCatalog`, o el `Provider`/`Bloc` de edición de fila).
- Comprobar si el `PUT /api/catalogs/<id>` reemplaza el documento completo (incluido `Rows`) en lugar de hacer una actualización parcial — si es así, cualquier `PUT` que se dispare con estado desactualizado puede sobrescribir cambios recientes.
- Revisar las extensiones permitidas en el `FilePicker` del cliente para confirmar si `.txt`/`.md` están excluidas.

### Nota de comportamiento de seguridad (correcto)

`GET /api/s3/presign` valida propiedad del recurso, no solo validez del token: un usuario autenticado no puede generar presigned URLs de objetos de otro usuario (`"error":"No autorizado"`), aunque su JWT tenga `isAdmin: true`. No se ha confirmado si esto es intencional (sin bypass para admins) o una limitación a revisar.

### Nota sobre manejo de errores del backend (mejorable)

Al enviar un `POST /api/auth/login` sin body, el backend devuelve una excepción interna sin capturar (`FormatException: Unexpected end of input`) en lugar de un `400` controlado. Recomendable envolver el parseo JSON en un `try/catch` que devuelva un mensaje de validación estándar, para no exponer detalles internos de implementación.

## 10. Pendientes / por confirmar — CERRADO (6 de septiembre de 2026)

Todos los puntos se investigaron con el script `diagnostico-edfcat.sh` (ver sección 11). Resultado:

- **`/health` público**: confirmado como fallback del SPA (cualquier ruta fuera de `/api/` cae al `index.html` de Flutter). Internamente, el contenedor sí expone un `/health` real usado como `HEALTHCHECK` de Docker cada 30s — visible en logs solo desde dentro, nunca desde fuera.
- **`/stats`**: descartado como ruta pública real — `/stats` (sin `/api`) es el mismo fallback del SPA. `/api/users/stats` sí es una ruta real del backend, pero devuelve `"No autorizado"` con un token de usuario admin normal — probablemente reservada a un rol/scope superior no identificado. No bloqueante, no se investiga más salvo que se necesite ese dato en el futuro.
- **`/api/auth/refresh`**: confirmado. Recibe el token de acceso actual en `Authorization: Bearer` y devuelve un token JWT nuevo — no usa un refresh token separado en el body/cookie pese a existir una colección `refresh_tokens` en Mongo (que aparentemente se usa para otro propósito, p. ej. invalidación en logout, no confirmado).
- **Campos de `POST /api/auth/login`**: confirmado que solo son `emailOrUsername` y `password` — no hay rastro en el binario de `rememberMe`, `deviceId` ni similares.
- **Bug de sincronización S3↔Mongo (sección 9)**: se intentó rastrear vía la colección `audit_logs`, pero **esa colección pertenece a otra aplicación** (contenido en español, referencias a Flask/`flask_debug.log`, backups — no relacionado con `edfcatalogo-api`, que es Dart). Hallazgo colateral importante: `edfcatalogo-api` y `catalogotablas.edefrutos2020.com` **comparten el mismo cluster/base de datos de MongoDB Atlas** (`edf_catalogotablas`), aunque son aplicaciones independientes. El diagnóstico del bug de sincronización sigue pendiente y requiere revisar el código Flutter directamente (no hay rastro a nivel de servidor/BD que lo explique).

## 12. Repositorio y despliegue

**Repositorio (monorepo, frontend + backend):**
```
https://github.com/edfrutos/EDFCatalogoMultiplatform.git
```

`/opt/edfcatalogo` en el servidor es un checkout git de este repositorio (rama `main`), no solo una carpeta de despliegue — confirmado con `git remote -v` / `git status` / `git log`.

### Flujo de despliegue (`scripts/deploy.sh`)

Se ejecuta **desde el Mac Studio** (no desde el servidor), requiere `flutter` en el PATH local y SSH configurado hacia `root@208.76.221.20:2222`:

1. `flutter build web --release` (local).
2. `rsync` del build hacia el webroot de Plesk (`/var/www/vhosts/efjdefrutos.com/edfcat.efjdefrutos.com/`), por SSH puerto 2222.
3. Por SSH en el servidor: `git pull --ff-only` en `/opt/edfcatalogo`, luego `docker compose -f docker/docker-compose.prod.yml up -d --build api`.

```bash
# Despliegue habitual (desde el Mac)
./scripts/deploy.sh

# Solo ficheros web, sin tocar la API
SKIP_API=1 ./scripts/deploy.sh
```

Otros scripts de build presentes en el repo: `build_macos_dmg.sh`, `build_linux_release.sh`, `build_linux_release_docker.sh`, `build_android.sh`.

### Commits recientes relevantes (útiles para el bug de sección 9)

```
7905bee fix(docker): healthcheck de la API siempre en unhealthy (wget no existe en scratch)
f501ee2 fix(docker): build de la API rompía por la dependencia de path a edfcatalogo_crypto
79c5cc8 refactor(s3,auth): centralizar firma AWS SigV4, tipos MIME y hash de contraseñas en edfcatalogo_crypto
a867647 fix(drive): revalidar refresh token y re-autenticar automáticamente si caduca
ad207dc fix(mongo): nombre de BD duplicado en la URI de conexión (nativo)
```

El commit `79c5cc8` (refactor de S3/tipos MIME) es el candidato más probable a estar relacionado con el bug de sincronización de ficheros descrito en la sección 9 — pendiente de revisión.

## 13. Script de diagnóstico

Se creó `diagnostico-edfcat.sh` — script de solo lectura que agrupa las comprobaciones repetidas de Docker, S3, MongoDB y API en una sola ejecución, con secciones invocables por separado:

```bash
./diagnostico-edfcat.sh              # ejecuta todo
./diagnostico-edfcat.sh docker       # solo estado/logs del contenedor
./diagnostico-edfcat.sh s3           # config .env enmascarada + listado real del bucket
./diagnostico-edfcat.sh mongo        # colecciones + documento de un catálogo
./diagnostico-edfcat.sh api          # healthcheck + consulta autenticada
./diagnostico-edfcat.sh pendientes   # las comprobaciones de este apartado
```

Requiere rellenar la cabecera de configuración del script (`CATALOG_ID`, `OWNER_ID`, credenciales de login opcionales) antes de usar las secciones que dependen de un catálogo concreto o de autenticación.

## 17. Bug 5 — `bad auth` en MongoDB tras un despliegue (18 de septiembre de 2026, CERRADO)

**Síntoma:** tras un despliegue normal con `./scripts/deploy.sh` (solo cambios de frontend web, sin tocar `api/` ni `.env`), el login dejó de funcionar. Logs del contenedor mostraban en bucle:

```
❌ Error conectando a MongoDB: MongoDart Error: bad auth : authentication failed
```

`docker ps -a` confirmó que el contenedor estaba en **crash-loop** (`Restarting (1)` cada pocos segundos) — de ahí que el healthcheck interno diera `HTTP:000` (connection refused, el proceso no llegaba a levantar el listener).

**Diagnóstico:** se descartó que fuera el despliegue, el driver Dart o Docker reproduciendo el mismo `bad auth` con `mongosh` directamente en el servidor, usando la URI tal cual está en `/opt/edfcatalogo/.env` — mismo error, sin pasar por el contenedor. El usuario de la URI (`edefrutos`) coincidía con el `.env` local que sí funciona. Conclusión: la contraseña en el `.env` del servidor estaba obsoleta/revocada en MongoDB Atlas.

**Causa raíz:** `scripts/deploy.sh` **nunca sincroniza `.env`** con el servidor (solo `build/web/` vía rsync y `git pull` del código — `.env` está en `.gitignore` a propósito, por seguridad, ver [`docs/misc/SECURITY_INCIDENT.md`](misc/SECURITY_INCIDENT.md)). En algún momento se rotó la contraseña del usuario de MongoDB Atlas y se actualizó el `.env` local, pero nunca se propagó manualmente al `.env` de producción — quedó con una credencial obsoleta hasta que un despliegue expuso el problema (coincidencia temporal, no causa).

**Corrección:** actualizar `MONGO_URI` en `/opt/edfcatalogo/.env` con la contraseña vigente y recrear el contenedor para que recargue las variables de entorno:

```bash
# En el servidor, tras editar /opt/edfcatalogo/.env
cd /opt/edfcatalogo
docker compose -f docker/docker-compose.prod.yml up -d --force-recreate api
```

Un `docker compose restart api` simple no es suficiente — no siempre relee el `env_file` del contenedor existente; hace falta `--force-recreate`.

**Verificación:** contenedor `Up (healthy)`, `curl http://127.0.0.1:8089/health` (endpoint **interno**, sin prefijo `/api/` — ese prefijo solo existe detrás del proxy nginx/Plesk) responde `200`, y login confirmado funcionando en producción.

**Lección para futuros despliegues:** si se rota la contraseña de MongoDB Atlas (o cualquier credencial en `.env`), hay que actualizar **manualmente** `/opt/edfcatalogo/.env` en el servidor — `deploy.sh` no lo hace ni debe hacerlo automáticamente. Al diagnosticar, usar siempre `/health` (no `/api/health`) al consultar el contenedor directamente en `127.0.0.1:8089`.
