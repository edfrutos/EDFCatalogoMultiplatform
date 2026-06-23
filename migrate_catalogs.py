#!/usr/bin/env python3
"""
Migración de esquema de catálogos MongoDB — EDFCatalogo
=======================================================
Migra documentos de la colección 'spreadsheets' (Python antiguo)
y actualiza documentos de formato antiguo en 'catalogs' al esquema
que usa la app Flutter.

Esquema destino (colección 'catalogs'):
  _id, Name, Description, Category, Headers, Rows, LegacyRows,
  Miniatura, userId, Owner, CreatedBy, CreatedAt, UpdatedAt

Paths S3 antiguos (/admin/s3/FILENAME) → URL completa S3.
Las filas antiguas (planas) → estructura Data + Files.

Uso:
  python3.12 migrate_catalogs.py            # dry-run (solo muestra cambios)
  python3.12 migrate_catalogs.py --apply    # aplica los cambios en MongoDB
"""

import sys
import os
import time
from datetime import datetime, timezone
from bson import ObjectId

try:
    from pymongo import MongoClient
except ImportError:
    print("❌ pymongo no instalado. Ejecuta: pip3.12 install pymongo")
    sys.exit(1)

DRY_RUN = "--apply" not in sys.argv

# ─── Configuración ────────────────────────────────────────────────────────────

S3_BASE = "https://edfcatalogotablas-sp.s3.eu-south-2.amazonaws.com"

ENV_PATH = "/Volumes/ESSAGER/__01.-Proyectos/EDFCatalogoMultiplatform/.env"

# Palabras clave para detectar columnas de tipo fichero por nombre
FILE_COL_KEYWORDS = {
    "multimedia": "Multimedia",
    "video": "Multimedia",
    "document": "Document",
    "documento": "Document",
    "doc": "Document",
    "archivo": "Document",
    "imagen": "Image",
    "image": "Image",
    "foto": "Image",
    "photo": "Image",
    "imágenes": "Image",
    "imagenes": "Image",
}

# ─── Leer .env ────────────────────────────────────────────────────────────────


def load_env(path):
    uri, db_name = "", ""
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("MONGO_URI="):
                    uri = line.split("=", 1)[1].strip()
                elif line.startswith("MONGO_DB="):
                    db_name = line.split("=", 1)[1].strip()
    except FileNotFoundError:
        print(f"❌ No se encontró el .env en: {path}")
        sys.exit(1)
    if not uri or not db_name:
        print("❌ MONGO_URI o MONGO_DB no encontrados en .env")
        sys.exit(1)
    return uri, db_name


# ─── Helpers ──────────────────────────────────────────────────────────────────


def parse_date(value):
    """Convierte distintos formatos de fecha a datetime UTC."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, dict) and "$date" in value:
        d = value["$date"]
        if isinstance(d, int):
            return datetime.fromtimestamp(d / 1000, tz=timezone.utc)
        if isinstance(d, str):
            return datetime.fromisoformat(d.replace("Z", "+00:00"))
    if isinstance(value, str):
        value = value.strip()
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
        # Formato "2026-04-23 11:37:28.958000"
        try:
            dt = datetime.strptime(value[:26], "%Y-%m-%d %H:%M:%S.%f")
            return dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
        try:
            dt = datetime.strptime(value[:19], "%Y-%m-%d %H:%M:%S")
            return dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None


def to_s3_url(path):
    """Convierte un path /admin/s3/FILENAME a URL completa S3."""
    if not path or not isinstance(path, str):
        return None
    path = path.strip()
    if not path:
        return None
    if path.startswith("https://"):
        return path  # ya es URL completa
    if path.startswith("/admin/s3/"):
        filename = path[len("/admin/s3/") :]
        return f"{S3_BASE}/{filename}"
    # Fallback: asumir que es solo el nombre del fichero
    return f"{S3_BASE}/{path}"


def to_s3_url_list(value):
    """Convierte valor (str o list) a lista de URLs S3 filtradas de None."""
    if value is None:
        return []
    if isinstance(value, str):
        url = to_s3_url(value)
        return [url] if url else []
    if isinstance(value, list):
        result = []
        for v in value:
            if isinstance(v, str) and v.strip():
                url = to_s3_url(v.strip())
                if url:
                    result.append(url)
        return result
    return []


def looks_like_file_value(value):
    """True si el valor parece ser un path/URL de fichero."""
    if isinstance(value, str):
        v = value.strip()
        return v.startswith("/admin/s3/") or "amazonaws.com" in v
    if isinstance(value, list):
        return any(looks_like_file_value(v) for v in value)
    return False


def detect_file_type_by_column(col_name):
    """
    Devuelve 'Image', 'Document', 'Multimedia' o None
    basándose en el nombre de la columna.
    """
    lower = col_name.lower().strip()
    # Coincidencia exacta primero
    if lower in FILE_COL_KEYWORDS:
        return FILE_COL_KEYWORDS[lower]
    # Coincidencia parcial
    for kw, file_type in FILE_COL_KEYWORDS.items():
        if kw in lower:
            return file_type
    return None


def now_iso():
    return datetime.now(tz=timezone.utc).isoformat()


def unique_row_id():
    """Genera un ID único basado en timestamp (como hace Flutter)."""
    return str(int(time.time() * 1000))


def str_id(oid):
    """Convierte ObjectId, dict $oid, o string a string hex."""
    if oid is None:
        return ""
    if isinstance(oid, ObjectId):
        return str(oid)
    if isinstance(oid, dict) and "$oid" in oid:
        return oid["$oid"]
    return str(oid)


# ─── Migración de filas ───────────────────────────────────────────────────────


def migrate_row(old_row, headers, index):
    """
    Convierte una fila de formato antiguo (plana) al nuevo formato Flutter
    con subcampos Data + Files.
    """
    row_id = str(int(time.time() * 1000) + index)

    data = {}
    files_image = None
    files_images = []
    files_document = None
    files_documents = []
    files_multimedia = None
    files_multimedia_files = []

    # ── Procesar columnas del header ────────────────────────────────────────
    for col in headers:
        val = old_row.get(col)

        if val is None:
            data[col] = ""
            continue

        file_type = detect_file_type_by_column(col)

        if file_type and looks_like_file_value(val):
            # Extraer a Files
            urls = to_s3_url_list(val)
            if file_type == "Image":
                if urls:
                    if not files_image:
                        files_image = urls[0]
                        files_images.extend(urls[1:])
                    else:
                        files_images.extend(urls)
            elif file_type == "Document":
                if urls:
                    if not files_document:
                        files_document = urls[0]
                        files_documents.extend(urls[1:])
                    else:
                        files_documents.extend(urls)
            elif file_type == "Multimedia":
                if urls:
                    if not files_multimedia:
                        files_multimedia = urls[0]
                        files_multimedia_files.extend(urls[1:])
                    else:
                        files_multimedia_files.extend(urls)
            # En Data dejamos vacío (era una URL, no texto descriptivo)
            data[col] = ""
        else:
            # Texto normal → va a Data como string
            if isinstance(val, list):
                data[col] = ", ".join(str(v) for v in val if v)
            else:
                data[col] = str(val) if val is not None else ""

    # ── Procesar claves especiales legacy ───────────────────────────────────
    # images / imagen_urls / _imagenes → Files.Image / Files.Images
    for key in ["images", "_imagenes", "Imagenes", "imagenes"]:
        val = old_row.get(key)
        if val:
            urls = to_s3_url_list(val)
            for url in urls:
                if not files_image:
                    files_image = url
                elif url not in files_images:
                    files_images.append(url)

    for key in ["imagen_urls"]:
        val = old_row.get(key)
        if val:
            urls = to_s3_url_list(val)
            for url in urls:
                if not files_image:
                    files_image = url
                elif url not in files_images and url != files_image:
                    files_images.append(url)

    # Documentos como lista separada (clave "Documentos" o "documentos_urls")
    for key in ["documentos_urls", "_documentos"]:
        val = old_row.get(key)
        if val:
            urls = to_s3_url_list(val)
            for url in urls:
                if not files_document:
                    files_document = url
                elif url not in files_documents:
                    files_documents.append(url)

    # Si "Documentos" es una lista de paths (no de textos) y no fue procesado
    docs_val = old_row.get("Documentos") or old_row.get("documentos")
    if isinstance(docs_val, list) and looks_like_file_value(docs_val):
        urls = to_s3_url_list(docs_val)
        for url in urls:
            if not files_document:
                files_document = url
            elif url not in files_documents:
                files_documents.append(url)

    # ── Construir Files ─────────────────────────────────────────────────────
    files_out = {}
    if files_image:
        files_out["Image"] = files_image
    files_out["Images"] = list(dict.fromkeys(files_images))  # dedup preservando orden
    if files_document:
        files_out["Document"] = files_document
    files_out["Documents"] = list(dict.fromkeys(files_documents))
    if files_multimedia:
        files_out["Multimedia"] = files_multimedia
    files_out["MultimediaFiles"] = list(dict.fromkeys(files_multimedia_files))
    files_out["FileTitles"] = {}

    return {
        "_id": row_id,
        "originalId": row_id,
        "Data": data,
        "Files": files_out,
        "CreatedAt": now_iso(),
        "UpdatedAt": now_iso(),
    }


# ─── Migración de catálogo ────────────────────────────────────────────────────


def is_old_format(doc):
    """
    True si el documento es de formato antiguo (Python backend).
    Criterios:
    - Tiene 'headers' minúscula (en lugar de 'Headers')
    - O tiene 'rows' planas sin subcampos Data/Files
    - O tiene 'owner'/'created_by' como username string (no ObjectId)
    """
    has_old_headers = "headers" in doc and "Headers" not in doc
    has_old_owner = ("owner" in doc or "created_by" in doc) and "Owner" not in doc
    # Rows planas: si la primera fila no tiene 'Data' ni 'Files'
    rows = doc.get("Rows") or doc.get("rows") or []
    has_flat_rows = False
    if rows and isinstance(rows, list) and len(rows) > 0:
        first = rows[0]
        if isinstance(first, dict) and "Data" not in first and "Files" not in first:
            has_flat_rows = True
    return has_old_headers or has_old_owner or has_flat_rows


def build_migrated_catalog(doc, user_lookup, catalog_id_str):
    """
    Construye el documento migrado al esquema Flutter.
    user_lookup: dict {username: ObjectId_str, email: ObjectId_str, ...}
    catalog_id_str: el _id del catálogo como string hex
    """
    # ── Nombre / Descripción ────────────────────────────────────────────────
    name = doc.get("Name") or doc.get("name") or "Sin nombre"
    description = doc.get("Description") or doc.get("description") or ""

    # ── Columnas ────────────────────────────────────────────────────────────
    headers = doc.get("Headers") or doc.get("headers") or doc.get("columns") or []
    if not isinstance(headers, list):
        headers = list(headers)
    headers = [str(h) for h in headers]

    # ── Owner → ObjectId ────────────────────────────────────────────────────
    owner_raw = (
        doc.get("Owner")
        or doc.get("owner")
        or doc.get("created_by")
        or doc.get("userId")
        or doc.get("CreatedBy")
        or ""
    )
    # Si ya parece un ObjectId (hex 24 chars), usarlo directamente
    owner_str = str(owner_raw).strip().strip('"').strip("'")
    if owner_str.startswith("ObjectId("):
        # "ObjectId("6a390cf61b97559848000000")" → extraer hex
        owner_str = owner_str.replace("ObjectId(", "").replace(")", "").strip("\"'")

    # Si es un username/email, buscar su ObjectId en users
    if owner_str and len(owner_str) != 24:
        # Buscar por username o email
        resolved = (
            user_lookup.get(owner_str)
            or user_lookup.get(doc.get("email", ""))
            or user_lookup.get(doc.get("owner_name", ""))
        )
        if resolved:
            owner_str = resolved
        else:
            print(
                f"   ⚠️  No se encontró usuario para owner='{owner_str}' — se deja como string"
            )

    # ── Miniatura ────────────────────────────────────────────────────────────
    miniatura_raw = (
        doc.get("Miniatura")
        or doc.get("miniatura")
        or doc.get("Thumbnail")
        or doc.get("thumbnailUrl")
    )
    miniatura = to_s3_url(miniatura_raw) if miniatura_raw else None

    # ── Filas ────────────────────────────────────────────────────────────────
    raw_rows = doc.get("Rows") or doc.get("rows") or []

    migrated_rows = []
    legacy_rows_list = []

    for i, row in enumerate(raw_rows):
        if not isinstance(row, dict):
            continue

        # ¿Ya tiene el nuevo formato (Data + Files)?
        if "Data" in row or "Files" in row:
            # Posiblemente ya migrado; asegurarse de que Files.Image/Multimedia
            # tienen URLs completas (no paths /admin/s3/)
            row = fix_existing_row_files(row)
            migrated_rows.append(row)
        else:
            # Formato plano antiguo
            legacy_rows_list.append(row)  # guardar original
            migrated_rows.append(migrate_row(row, headers, i))

    # ── Fechas ───────────────────────────────────────────────────────────────
    created_at = (
        parse_date(doc.get("CreatedAt"))
        or parse_date(doc.get("created_at"))
        or datetime.now(tz=timezone.utc)
    )
    updated_at = datetime.now(tz=timezone.utc)

    # ── Documento final ──────────────────────────────────────────────────────
    result = {
        "_id": catalog_id_str,
        "Name": name,
        "Description": description,
        "Category": doc.get("Category") or doc.get("category") or "",
        "Headers": headers,
        "Rows": migrated_rows,
        "LegacyRows": legacy_rows_list,  # backup de filas antiguas
        "userId": owner_str,
        "CreatedBy": owner_str,
        "Owner": owner_str,
        "CreatedAt": created_at.isoformat(),
        "UpdatedAt": updated_at.isoformat(),
    }
    if miniatura:
        result["Miniatura"] = miniatura

    return result


def fix_existing_row_files(row):
    """
    En filas ya con Data/Files, convierte paths /admin/s3/ a URLs completas.
    """
    files = row.get("Files") or row.get("files") or {}
    changed = False

    def fix_url(val):
        nonlocal changed
        if isinstance(val, str) and val.startswith("/admin/s3/"):
            changed = True
            return to_s3_url(val)
        return val

    def fix_list(lst):
        nonlocal changed
        return [fix_url(v) for v in lst] if isinstance(lst, list) else lst

    for key in ["Image", "image", "Document", "document", "Multimedia", "multimedia"]:
        if key in files:
            files[key] = fix_url(files[key])
    for key in [
        "Images",
        "images",
        "Documents",
        "documents",
        "MultimediaFiles",
        "multimediaFiles",
    ]:
        if key in files:
            files[key] = fix_list(files[key])

    if changed:
        row = dict(row)
        if "Files" in row:
            row["Files"] = files
        elif "files" in row:
            row["files"] = files

    return row


# ─── Carga usuarios (para resolver username → ObjectId) ───────────────────────


def build_user_lookup(users_col):
    """
    Devuelve un dict {username: ObjectId_str, email: ObjectId_str, name: ObjectId_str}
    para resolver referencias de owner.
    """
    lookup = {}
    for u in users_col.find(
        {},
        {
            "_id": 1,
            "username": 1,
            "email": 1,
            "name": 1,
            "Username": 1,
            "Email": 1,
            "Name": 1,
        },
    ):
        oid = str_id(u["_id"])
        for field in ["username", "Username", "email", "Email", "name", "Name"]:
            val = u.get(field)
            if val:
                lookup[str(val).strip()] = oid
    return lookup


# ─── Comparación de documentos ────────────────────────────────────────────────


def diff_docs(old_doc, new_doc):
    """Devuelve lista de strings describiendo las diferencias campo a campo."""
    diffs = []
    all_keys = set(old_doc.keys()) | set(new_doc.keys()) - {"_id"}

    for k in sorted(all_keys):
        if k == "_id":
            continue
        old_val = old_doc.get(k, "<ausente>")
        new_val = new_doc.get(k, "<ausente>")

        if k == "Rows":
            old_count = len(old_val) if isinstance(old_val, list) else "?"
            new_count = len(new_val) if isinstance(new_val, list) else "?"
            if old_count != new_count:
                diffs.append(f"  Rows: {old_count} filas → {new_count} filas")
            elif old_val != new_val:
                diffs.append(
                    f"  Rows: misma cantidad ({new_count}) pero diferente estructura"
                )
            continue

        if k == "LegacyRows":
            if new_val and old_val != new_val:
                count = len(new_val) if isinstance(new_val, list) else "?"
                diffs.append(f"  LegacyRows: se guardan {count} filas originales")
            continue

        old_str = repr(old_val)[:60]
        new_str = repr(new_val)[:60]

        if old_val != new_val:
            if old_val == "<ausente>":
                diffs.append(f"  ✚ {k}: {new_str}")
            elif new_val == "<ausente>":
                diffs.append(f"  🗑  {k} eliminado (era: {old_str})")
            else:
                diffs.append(f"  {k}: {old_str} → {new_str}")

    return diffs


# ─── Main ─────────────────────────────────────────────────────────────────────


def main():
    print(f"\n{'🔍 DRY-RUN' if DRY_RUN else '🚀 APLICANDO'} — Migración de catálogos")
    print("=" * 60)

    uri, db_name = load_env(ENV_PATH)
    print(f"BD: {db_name}\n")

    client = MongoClient(uri)
    db = client[db_name]

    users_col = db["users"]
    catalogs_col = db["catalogs"]
    spreadsheets_col = db["spreadsheets"]

    # Construir tabla username/email → ObjectId
    user_lookup = build_user_lookup(users_col)
    print(f"👥 Usuarios en lookup: {len(user_lookup)} entradas\n")

    total_migrated = 0
    total_skipped = 0
    total_inserted = 0

    # ── 1. Migrar documentos en 'catalogs' de formato antiguo ────────────────
    print("─── Colección: catalogs ─────────────────────────────────────────")
    catalog_docs = list(catalogs_col.find({}))
    print(f"📋 Documentos en 'catalogs': {len(catalog_docs)}\n")

    for doc in catalog_docs:
        oid_str = str_id(doc["_id"])
        name = doc.get("Name") or doc.get("name") or oid_str

        if not is_old_format(doc):
            print(f"✅ [{oid_str[:8]}…] '{name}' — ya en formato nuevo, sin cambios")
            total_skipped += 1
            continue

        new_doc = build_migrated_catalog(doc, user_lookup, oid_str)
        diffs = diff_docs(doc, new_doc)

        if not diffs:
            print(f"✅ [{oid_str[:8]}…] '{name}' — sin cambios detectados")
            total_skipped += 1
            continue

        print(f"🔄 [{oid_str[:8]}…] '{name}'")
        for d in diffs:
            print(d)

        if not DRY_RUN:
            catalogs_col.replace_one(
                {"_id": doc["_id"]},
                {"_id": doc["_id"], **{k: v for k, v in new_doc.items() if k != "_id"}},
            )
            print(f"   ✅ Actualizado")

        total_migrated += 1
        print()

    # ── 2. Migrar 'spreadsheets' → insertar en 'catalogs' ───────────────────
    print("\n─── Colección: spreadsheets → catalogs ──────────────────────────")
    ss_docs = list(spreadsheets_col.find({}))
    print(f"📋 Documentos en 'spreadsheets': {len(ss_docs)}\n")

    # Obtener IDs ya existentes en catalogs para evitar duplicados
    existing_ids = set(str_id(d["_id"]) for d in catalogs_col.find({}, {"_id": 1}))

    for doc in ss_docs:
        oid_str = str_id(doc["_id"])
        name = doc.get("name") or doc.get("Name") or oid_str

        if oid_str in existing_ids:
            print(f"⏭  [{oid_str[:8]}…] '{name}' — ya existe en 'catalogs', saltando")
            total_skipped += 1
            continue

        new_doc = build_migrated_catalog(doc, user_lookup, oid_str)

        print(f"📥 [{oid_str[:8]}…] '{name}' — se insertará en 'catalogs'")
        print(f"   Name:     {new_doc['Name']}")
        print(f"   Headers:  {new_doc['Headers']}")
        print(f"   Owner:    {new_doc['Owner']}")
        print(f"   Miniatura:{new_doc.get('Miniatura', '(ninguna)')}")
        rows_n = len(new_doc.get("Rows", []))
        print(f"   Rows:     {rows_n} fila(s)")

        if not DRY_RUN:
            catalogs_col.insert_one(
                {"_id": doc["_id"], **{k: v for k, v in new_doc.items() if k != "_id"}}
            )
            print(f"   ✅ Insertado")

        total_inserted += 1
        print()

    # ── Resumen ──────────────────────────────────────────────────────────────
    print("=" * 60)
    print(f"{'[DRY-RUN] ' if DRY_RUN else ''}Resultado:")
    print(f"  🔄 Catalogs actualizados (o a actualizar): {total_migrated}")
    print(f"  📥 Spreadsheets insertados (o a insertar): {total_inserted}")
    print(f"  ✅ Sin cambios / ya existentes:            {total_skipped}")

    if DRY_RUN and (total_migrated + total_inserted) > 0:
        print(f"\n⚠️  Para aplicar los cambios ejecuta:")
        print(f"    python3.12 {sys.argv[0]} --apply\n")

    client.close()


if __name__ == "__main__":
    main()
