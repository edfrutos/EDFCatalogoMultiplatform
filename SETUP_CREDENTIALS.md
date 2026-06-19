# 🔐 SETUP DE CREDENCIALES - EDFCatalogoMultiplatform

## ⚠️ ADVERTENCIA DE SEGURIDAD

**NUNCA** compartas públicamente:
- ❌ AWS Access Keys
- ❌ AWS Secret Keys
- ❌ MongoDB Connection Strings
- ❌ Gmail App Passwords
- ❌ Archivos `.env` o `appsettings.local.json`

---

## 🚀 PROCESO SEGURO DE CONFIGURACIÓN

### PASO 1: Rotar Credenciales (INMEDIATO)

Las credenciales compartidas están comprometidas. Debes generarlas nuevamente:

#### AWS S3
```
1. Ir a: https://console.aws.amazon.com/
2. IAM > Users > [Tu Usuario] > Security Credentials
3. Access Keys > Deactivate la clave comprometida
4. Click "Create access key"
5. Guardar en lugar seguro (no en texto plano)
6. Actualizar en .env localmente
```

#### MongoDB Atlas
```
1. Ir a: https://cloud.mongodb.com/
2. Database Access > Edit > Change Password
3. Generar contraseña fuerte
4. Actualizar MONGO_URI en .env localmente
5. Verificar conexión
```

#### Gmail
```
1. Ir a: https://myaccount.google.com/
2. Security > App passwords (abajo)
3. Revoke la contraseña comprometida
4. Generate nueva contraseña de 16 caracteres
5. Copiar a lugar seguro (no en texto plano)
6. Actualizar GOOGLE_APP_PASSWORD en .env localmente
```

---

## 📁 CONFIGURACIÓN LOCAL (POR LENGUAJE)

### 🎯 Flutter

```bash
# 1. Navegar al proyecto
cd languages/flutter

# 2. Crear archivo .env desde template
cp config/.env.example .env

# 3. Editar .env con tus credenciales NUEVAS Y ROTADAS
nano .env  # o tu editor favorito

# 4. Contenido .env debe ser:
MONGO_URI=mongodb+srv://edfrutos:TU_NUEVA_PASSWORD@cluster0.abpvipa.mongodb.net/
MONGO_DB=edf_multiplatform
S3_BUCKET_NAME=edf-catalogotablas-sp
AWS_ACCESS_KEY_ID=TU_NUEVA_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=TU_NUEVA_SECRET_KEY
AWS_REGION=eu-south-1
USE_S3=true
GOOGLE_EMAIL=edfrutos@gmail.com
GOOGLE_APP_PASSWORD=TU_NUEVA_APP_PASSWORD

# 5. Verificar que .env NO está en git
grep ".env" .gitignore  # Debe estar listado

# 6. Ejecutar
flutter pub get
flutter run
```

### 🖥️ Swift

```bash
# 1. Navegar al proyecto
cd languages/swift

# 2. Crear archivo .env desde template
cp config/.env.example .env

# 3. Editar .env con tus credenciales
nano .env

# 4. Cargar automáticamente al iniciar la app
# (El Package.swift ya está configurado para cargar .env)

# 5. Ejecutar
swift run
```

### 🌐 C#

```bash
# 1. Navegar al proyecto
cd languages/csharp

# 2. Crear archivo appsettings.local.json
cp config/appsettings.example.json appsettings.local.json

# 3. Editar con tus credenciales NUEVAS
nano appsettings.local.json

# 4. Contenido debe ser:
{
  "MongoDB": {
    "ConnectionString": "mongodb+srv://edfrutos:TU_NUEVA_PASSWORD@cluster0.abpvipa.mongodb.net/",
    "DatabaseName": "edf_multiplatform"
  },
  "AWS": {
    "AccessKey": "TU_NUEVA_ACCESS_KEY",
    "SecretKey": "TU_NUEVA_SECRET_KEY",
    "Region": "eu-south-1",
    "BucketName": "edf-catalogotablas-sp"
  },
  "Gmail": {
    "SenderEmail": "edfrutos@gmail.com",
    "AppPassword": "TU_NUEVA_APP_PASSWORD"
  }
}

# 5. Verificar que appsettings.local.json NO está en git
grep "appsettings.local.json" .gitignore  # Debe estar

# 6. Ejecutar
dotnet restore
dotnet run
```

### 🐍 Python

```bash
# 1. Navegar al proyecto
cd languages/python

# 2. Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# 3. Crear archivo .env desde template
cp config/.env.example .env

# 4. Editar .env con tus credenciales NUEVAS
nano .env

# 5. Contenido .env debe ser:
MONGO_URI=mongodb+srv://edfrutos:TU_NUEVA_PASSWORD@cluster0.abpvipa.mongodb.net/
MONGO_DB=edf_multiplatform
S3_BUCKET_NAME=edf-catalogotablas-sp
AWS_ACCESS_KEY_ID=TU_NUEVA_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=TU_NUEVA_SECRET_KEY
AWS_REGION=eu-south-1
GOOGLE_EMAIL=edfrutos@gmail.com
GOOGLE_APP_PASSWORD=TU_NUEVA_APP_PASSWORD

# 6. Instalar dependencias
pip install -r requirements.txt

# 7. Ejecutar
python run_server.py
```

---

## ✅ VERIFICACIÓN DE CONECTIVIDAD

### Verificar AWS S3

```python
# Python
import boto3
from dotenv import load_dotenv
import os

load_dotenv()

s3 = boto3.client(
    's3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
    region_name=os.getenv('AWS_REGION')
)

# Intentar listar objetos
try:
    response = s3.list_objects_v2(Bucket=os.getenv('S3_BUCKET_NAME'), MaxKeys=1)
    print("✅ AWS S3 conectado correctamente")
except Exception as e:
    print(f"❌ Error en S3: {e}")
```

### Verificar MongoDB

```python
# Python
from pymongo import MongoClient
from dotenv import load_dotenv
import os

load_dotenv()

try:
    client = MongoClient(os.getenv('MONGO_URI'))
    db = client[os.getenv('MONGO_DB')]
    db.command('ping')
    print("✅ MongoDB conectado correctamente")
except Exception as e:
    print(f"❌ Error en MongoDB: {e}")
```

### Verificar Gmail

```python
# Python
import smtplib
from dotenv import load_dotenv
import os

load_dotenv()

try:
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(os.getenv('GOOGLE_EMAIL'), os.getenv('GOOGLE_APP_PASSWORD'))
    print("✅ Gmail conectado correctamente")
    server.quit()
except Exception as e:
    print(f"❌ Error en Gmail: {e}")
```

---

## 🔒 MEJORES PRÁCTICAS DE SEGURIDAD

### En tu máquina local:

1. ✅ **Usar archivos `.env` o `appsettings.local.json`**
   - Nunca en el código fuente
   - Siempre en `.gitignore`
   - Permisos restringidos (600)

2. ✅ **Credenciales específicas por entorno**
   - Desarrollo: credenciales de test
   - Producción: credenciales rotadas regularmente

3. ✅ **Nunca loguear credenciales**
   ```python
   # ❌ MAL
   print(f"Password: {password}")
   
   # ✅ BIEN
   print("Conectado a MongoDB")
   ```

4. ✅ **Usar variables de entorno del sistema en producción**
   ```bash
   # En producción (servidor)
   export MONGO_URI="mongodb+srv://..."
   export AWS_ACCESS_KEY_ID="..."
   ```

5. ✅ **Auditar acceso a credenciales**
   - AWS CloudTrail
   - MongoDB Audit Logs
   - Gmail Security Logs

---

## 📋 CHECKLIST FINAL

- [ ] Nuevas credenciales generadas en AWS, MongoDB, Gmail
- [ ] Credenciales antiguas desactivadas/revocadas
- [ ] `.env` o `appsettings.local.json` creado localmente
- [ ] Credenciales NUEVAS introducidas en archivos locales
- [ ] `.env` y `appsettings.local.json` están en `.gitignore`
- [ ] Conectividad probada (S3, MongoDB, Gmail)
- [ ] Aplicación ejecutable sin errores de conexión
- [ ] Archivo de configuración NO cometido a git
- [ ] Backups seguros de credenciales rotadas

---

## 🆘 PROBLEMAS COMUNES

### "Invalid credentials" en S3
```
✓ Verificar que Access Key está activo (no desactivado)
✓ Verificar que Secret Key es correcta
✓ Verificar que región es correcta
✓ Verificar que bucket existe en esa región
```

### "Failed to connect to MongoDB"
```
✓ Verificar MONGO_URI tiene contraseña nueva
✓ Verificar IP está en whitelist de MongoDB Atlas
✓ Verificar que cluster existe
✓ Usar: mongo "mongodb+srv://..." --eval "db.adminCommand('ping')"
```

### "Gmail authentication failed"
```
✓ Verificar que es App Password (16 caracteres), no contraseña normal
✓ Verificar que 2FA está habilitado en Google
✓ Verificar que email es correcto
✓ Revisar: myaccount.google.com/apppasswords
```

---

## 📞 REFERENCIA RÁPIDA

| Servicio | Archivo | Variable | Donde Obtener |
|----------|---------|----------|---------------|
| **AWS S3** | `.env` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | AWS Console > IAM > Users |
| **MongoDB** | `.env` | `MONGO_URI`, `MONGO_DB` | MongoDB Atlas > Connect |
| **Gmail** | `.env` | `GOOGLE_EMAIL`, `GOOGLE_APP_PASSWORD` | myaccount.google.com > Security |

---

**IMPORTANTE:** Este archivo NO contiene credenciales reales.  
Guarda esta documentación en un lugar seguro para referencia futura.

**Última actualización:** Abril 2025  
**Versión:** 1.0.0
