#!/usr/bin/env python3
"""
Migración de esquema de usuarios MongoDB — EDFCatalogo
======================================================
Estandariza todos los documentos de la colección 'users' al esquema
que usa la app Flutter (campos en minúsculas, nombres en inglés).

Esquema destino:
  _id, email, username, name, role, isAdmin,
  fullName, phone, company, address, occupation,
  profileImageUrl, isActive, createdAt, lastLoginAt,
  password, emailVerified, loginCount, failedAttempts,
  lockedUntil, mustChangePassword

Uso:
  python3 migrate_users.py            # modo dry-run (solo muestra cambios)
  python3 migrate_users.py --apply    # aplica los cambios en MongoDB
"""

import sys
import os
from datetime import datetime, timezone

try:
    from pymongo import MongoClient
except ImportError:
    print("❌ pymongo no instalado. Ejecuta: pip3 install pymongo")
    sys.exit(1)

DRY_RUN = "--apply" not in sys.argv

# ─── Leer .env ────────────────────────────────────────────────────────────────

ENV_PATH = os.path.join(
    os.path.dirname(__file__),
    "/Volumes/ESSAGER/__01.-Proyectos/EDFCatalogoMultiplatform/.env"
)

uri = ""
db_name = ""
try:
    with open(ENV_PATH) as f:
        for line in f:
            line = line.strip()
            if line.startswith("MONGO_URI="):
                uri = line.split("=", 1)[1].strip()
            elif line.startswith("MONGO_DB="):
                db_name = line.split("=", 1)[1].strip()
except FileNotFoundError:
    print(f"❌ No se encontró el .env en: {ENV_PATH}")
    sys.exit(1)

if not uri or not db_name:
    print("❌ MONGO_URI o MONGO_DB no encontrados en .env")
    sys.exit(1)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def parse_date(value):
    """Intenta convertir distintos formatos de fecha a datetime."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, dict) and "$date" in value:
        d = value["$date"]
        if isinstance(d, int):
            return datetime.fromtimestamp(d / 1000, tz=timezone.utc)
        if isinstance(d, str):
            return datetime.fromisoformat(d.replace("Z", "+00:00"))
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def get(doc, *keys, default=None):
    """Lee el primer key que exista en el documento."""
    for k in keys:
        if k in doc and doc[k] is not None:
            return doc[k]
    return default


def normalize_role(doc):
    """Devuelve 'admin' o 'user' leyendo cualquier variante del campo role."""
    raw = get(doc, "Role", "role", "isAdmin", default="user")
    if isinstance(raw, bool):
        return "admin" if raw else "user"
    s = str(raw).lower()
    return "admin" if s in ("admin", "true", "1") else "user"


# ─── Mapeo de documento ────────────────────────────────────────────────────────

def build_standardized(doc):
    """Construye el documento estandarizado a partir de cualquier versión."""

    role = normalize_role(doc)

    standardized = {
        # Identidad
        "email":    get(doc, "Email", "email", default=""),
        "username": get(doc, "Username", "username", default=""),
        "name":     get(doc, "Name", "name", "nombre", default=""),
        "role":     role,
        "isAdmin":  role == "admin",

        # Campos opcionales de perfil
        "fullName":        get(doc, "FullName", "fullName", "full_name"),
        "phone":           get(doc, "Phone", "phone"),
        "company":         get(doc, "Company", "company"),
        "address":         get(doc, "Address", "address"),
        "occupation":      get(doc, "Occupation", "occupation"),
        "profileImageUrl": get(doc, "ProfileImageUrl", "profileImageUrl",
                               "profile_image_url"),

        # Estado de cuenta
        "isActive":       bool(get(doc, "IsActive", "isActive",
                                   "is_active", "active", default=True)),
        "emailVerified":  bool(get(doc, "EmailVerified", "emailVerified",
                                   "email_verified", default=False)),
        "loginCount":     int(get(doc, "LoginCount", "loginCount",
                                  "login_count", default=0)),
        "failedAttempts": int(get(doc, "FailedAttempts", "failedAttempts",
                                  "failed_attempts", default=0)),
        "lockedUntil":    get(doc, "LockedUntil", "lockedUntil",
                              "locked_until"),
        "mustChangePassword": bool(get(doc, "MustChangePassword",
                                       "mustChangePassword",
                                       "must_change_password", default=False)),

        # Fechas
        "createdAt":   parse_date(get(doc, "CreatedAt", "createdAt",
                                      "created_at")),
        "lastLoginAt": parse_date(get(doc, "LastLoginAt", "lastLoginAt",
                                      "ultimo_login", "last_login_at")),
        "updatedAt":   datetime.now(tz=timezone.utc),
    }

    # Conservar password tal cual (campo sensible, no tocar el hash)
    pw = get(doc, "Password", "password")
    if pw:
        standardized["password"] = pw

    # Eliminar None para no sobrescribir con null campos que no existen
    return {k: v for k, v in standardized.items() if v is not None or k in (
        "fullName", "phone", "company", "address", "occupation",
        "profileImageUrl", "lockedUntil"
    )}


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"\n{'🔍 DRY-RUN' if DRY_RUN else '🚀 APLICANDO'} — BD: {db_name}")
    print("=" * 60)

    client = MongoClient(uri)
    db = client[db_name]
    col = db["users"]

    docs = list(col.find({}))
    print(f"📋 Documentos encontrados: {len(docs)}\n")

    migrated = 0
    skipped = 0

    for doc in docs:
        oid = doc["_id"]
        email = get(doc, "Email", "email", default="(sin email)")

        new_doc = build_standardized(doc)

        # Calcular diferencias
        diffs = []
        for k, v in new_doc.items():
            old_val = doc.get(k)
            if old_val != v:
                diffs.append(f"  {k}: {repr(old_val)!s:30} → {repr(v)}")

        # Detectar campos que se eliminarán (claves viejas que ya no estarán)
        old_keys = set(doc.keys()) - {"_id"}
        new_keys = set(new_doc.keys())
        removed = old_keys - new_keys - {"password"}  # password siempre se conserva
        for k in removed:
            diffs.append(f"  🗑  {k} (eliminado)")

        if not diffs:
            print(f"✅ {email} — sin cambios")
            skipped += 1
            continue

        print(f"🔄 {email}")
        for d in diffs:
            print(d)

        if not DRY_RUN:
            # Reemplazar el documento completo manteniendo el _id original
            col.replace_one({"_id": oid}, {"_id": oid, **new_doc})
            print(f"   ✅ Guardado")

        migrated += 1
        print()

    print("=" * 60)
    print(f"{'[DRY-RUN] ' if DRY_RUN else ''}Resultado:")
    print(f"  🔄 A migrar / migrados: {migrated}")
    print(f"  ✅ Sin cambios:         {skipped}")

    if DRY_RUN and migrated > 0:
        print(f"\n⚠️  Para aplicar los cambios ejecuta:")
        print(f"    python3 {sys.argv[0]} --apply\n")

    client.close()


if __name__ == "__main__":
    main()
