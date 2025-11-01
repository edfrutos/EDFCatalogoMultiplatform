# 🔧 Configuración del Archivo .env

## 📋 Pasos para Configurar

### 1. Crear el archivo .env

Crea un archivo llamado `.env` en la raíz del proyecto:

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
cp .env.example .env
```

### 2. Completar las Variables de Entorno

Abre el archivo `.env` y completa con tus credenciales reales:

```env
# MongoDB
MONGO_URI=mongodb+srv://usuario:password@cluster.mongodb.net/?retryWrites=true&w=majority
MONGO_DB=edfcatalogo

# AWS S3
AWS_ACCESS_KEY_ID=tu_access_key_real
AWS_SECRET_ACCESS_KEY=tu_secret_key_real
AWS_REGION=us-east-1
S3_BUCKET_NAME=tu-bucket-real
USE_S3=true

# Brevo (Sendinblue)
BREVO_API_KEY=tu_api_key_brevo
BREVO_SMTP_USERNAME=tu_usuario_smtp
BREVO_SMTP_PASSWORD=tu_password_smtp
BREVO_SMTP_SERVER=smtp-relay.brevo.com
BREVO_SMTP_PORT=587

# Notificaciones
NOTIFICATION_EMAIL_1=admin@tudominio.com

# Entorno
APP_ENV=development
LOG_LEVEL=info
```

### 3. Obtener las Credenciales

#### MongoDB Atlas
1. Ve a [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Crea o selecciona tu cluster
3. Ve a "Database Access" → crea un usuario
4. Ve a "Network Access" → añade tu IP
5. Ve a "Database" → "Connect" → "Connect your application"
6. Copia la URI de conexión

#### AWS S3
1. Ve a [AWS Console](https://console.aws.amazon.com/)
2. Crea un bucket S3 o usa uno existente
3. Ve a "IAM" → "Users" → crea un usuario con permisos S3
4. Genera Access Key ID y Secret Access Key

#### Brevo (Sendinblue)
1. Ve a [Brevo](https://www.brevo.com/)
2. Crea una cuenta o inicia sesión
3. Ve a "Settings" → "API Keys"
4. Genera una nueva API key
5. Para SMTP, usa las credenciales proporcionadas

### 4. Verificar la Configuración

Una vez creado el `.env`, puedes verificar que todo esté correcto:

```bash
./test_quick.sh
```

El script debería mostrar:
- ✅ Archivo .env encontrado

### 5. Importante: Seguridad

⚠️ **NUNCA** subas el archivo `.env` al repositorio Git. Ya está incluido en `.gitignore`.

---

## 🔍 Variables Requeridas

### Críticas (sin ellas la app no funcionará):
- `MONGO_URI` - Conexión a MongoDB
- `MONGO_DB` - Nombre de la base de datos

### Importantes (necesarias para funcionalidades clave):
- `AWS_ACCESS_KEY_ID` - Para subir archivos a S3
- `AWS_SECRET_ACCESS_KEY` - Para subir archivos a S3
- `AWS_REGION` - Región de AWS
- `S3_BUCKET_NAME` - Nombre del bucket S3
- `BREVO_API_KEY` - Para enviar emails

### Opcionales:
- `BREVO_SMTP_USERNAME` - Para SMTP (alternativa a API)
- `BREVO_SMTP_PASSWORD` - Para SMTP (alternativa a API)
- `NOTIFICATION_EMAIL_1` - Email para notificaciones
- `APP_ENV` - Entorno (development/production)
- `LOG_LEVEL` - Nivel de logging

---

## 🚀 Después de Configurar

Una vez que tengas el `.env` configurado:

```bash
# Instalar dependencias
flutter pub get

# Verificar errores
flutter analyze

# Ejecutar la aplicación
flutter run
```

---

## 📝 Notas

- Si tienes el archivo `.env` del proyecto Swift original, puedes copiar los valores de ahí
- Asegúrate de que las credenciales sean válidas y tengan los permisos necesarios
- En producción, usa variables de entorno del sistema o servicios de secretos

