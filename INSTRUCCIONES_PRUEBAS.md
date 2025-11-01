# 🚀 Instrucciones para Probar las Funcionalidades

## 📋 Pasos Iniciales

### 1. Verificar Dependencias

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
flutter pub get
```

### 2. Verificar Configuración

Asegúrate de que existe el archivo `.env` con las configuraciones necesarias:

```
MONGO_URI=mongodb+srv://...
MONGO_DB=edfcatalogo
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=...
S3_BUCKET_NAME=...
BREVO_API_KEY=...
```

### 3. Verificar Errores

```bash
flutter analyze
```

### 4. Ejecutar la Aplicación

```bash
# Para desarrollo
flutter run

# O específicamente para una plataforma:
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d ios
flutter run -d android
```

---

## 🧪 Secuencia de Pruebas Recomendada

### **FASE 1: Validación de Datos** (5-10 minutos)

#### 1.1 Registro de Usuario
1. Abre la app
2. Haz clic en "Registrarse" o "Crear cuenta"
3. Prueba cada campo:

   **Username:**
   - [ ] Deja vacío → debería mostrar error
   - [ ] Ingresa "ab" (2 caracteres) → debería mostrar error
   - [ ] Ingresa "usuario@" → debería mostrar error (caracteres especiales)
   - [ ] Ingresa "usuario123" → debería aceptar

   **Email:**
   - [ ] Deja vacío → debería mostrar error
   - [ ] Ingresa "email" → debería mostrar error (sin @)
   - [ ] Ingresa "email@" → debería mostrar error (incompleto)
   - [ ] Ingresa "usuario@example.com" → debería aceptar

   **Contraseña:**
   - [ ] Deja vacío → debería mostrar error
   - [ ] Ingresa "12345" (5 caracteres) → debería mostrar error
   - [ ] Ingresa "123456" (6 caracteres) → debería aceptar

   **Confirmar Contraseña:**
   - [ ] Ingresa diferente a la contraseña → debería mostrar error
   - [ ] Ingresa igual → debería aceptar

4. Verifica que los errores aparecen **en tiempo real** mientras escribes
5. Completa el formulario correctamente y registra un usuario

#### 1.2 Recuperación de Contraseña
1. Haz clic en "Olvidé mi contraseña"
2. Prueba:
   - [ ] Email inválido → debería mostrar error
   - [ ] Email válido → debería enviar código
3. Verifica que recibes el email con el código

#### 1.3 Restablecimiento de Contraseña
1. Ingresa el código recibido
2. Prueba:
   - [ ] Código con menos de 6 dígitos → error
   - [ ] Contraseña corta → error
   - [ ] Contraseñas no coinciden → error
3. Completa correctamente y verifica que se restablezca

#### 1.4 Añadir/Editar Filas
1. Inicia sesión
2. Abre un catálogo
3. Entra en modo edición
4. Haz clic en "Añadir fila"
5. Prueba:
   - [ ] Intenta guardar sin completar campos → deberían mostrar errores
   - [ ] Completa los campos → debería permitir guardar

---

### **FASE 2: Modo Offline** (10-15 minutos)

#### 2.1 Preparación
1. Asegúrate de tener algunos catálogos creados
2. Asegúrate de estar conectado a internet

#### 2.2 Activar Modo Offline
1. **Desactiva WiFi o datos móviles** en tu dispositivo/emulador
2. Verifica:
   - [ ] Aparece el indicador "Modo offline" en la parte superior
   - [ ] Los catálogos existentes siguen siendo visibles
   - [ ] Aparece el botón de sincronización (ícono de sync)

#### 2.3 Operaciones Offline
1. **Crear catálogo:**
   - [ ] Crea un nuevo catálogo sin conexión
   - [ ] Verifica que se guarde y aparezca en la lista
   - [ ] Nota: tendrá un ID temporal

2. **Editar catálogo:**
   - [ ] Edita un catálogo existente
   - [ ] Verifica que los cambios se guarden localmente

3. **Añadir filas:**
   - [ ] Abre un catálogo
   - [ ] Añade una nueva fila
   - [ ] Verifica que se guarde

4. **Eliminar catálogo:**
   - [ ] Elimina un catálogo (el que creaste offline)
   - [ ] Verifica que desaparezca de la lista

#### 2.4 Sincronización
1. **Activa WiFi o datos móviles nuevamente**
2. Verifica:
   - [ ] El indicador "Modo offline" desaparece
   - [ ] Las operaciones se sincronizan automáticamente (puede tomar unos segundos)
   
3. **Sincronización manual:**
   - [ ] Si aún aparece "Modo offline", presiona el botón de sincronización
   - [ ] Verifica que se completen las operaciones

4. **Verificar en servidor:**
   - [ ] Recarga los catálogos (pull to refresh)
   - [ ] Verifica que el catálogo creado offline ahora esté en el servidor
   - [ ] Verifica que los cambios se hayan aplicado

---

### **FASE 3: Paginación** (5-10 minutos)

#### 3.1 Paginación de Catálogos
1. Si tienes menos de 20 catálogos, crea más hasta tener al menos 25
2. Verifica:
   - [ ] Aparece información de paginación (ej: "1-20 de 25")
   - [ ] Navega con los botones anterior/siguiente
   - [ ] Se muestran diferentes catálogos en cada página
   - [ ] El botón "Cargar más" aparece al final de la lista
   - [ ] Al presionar "Cargar más", se cargan más elementos

#### 3.2 Paginación de Filas
1. Abre un catálogo con más de 50 filas (o crea más filas)
2. Verifica:
   - [ ] Aparece información de paginación de filas
   - [ ] Navega entre páginas
   - [ ] El ordenamiento funciona correctamente con la paginación

---

### **FASE 4: Búsqueda** (5 minutos)

#### 4.1 Búsqueda Simple
1. En la vista de catálogos, usa el campo de búsqueda
2. Prueba:
   - [ ] Buscar por nombre de catálogo
   - [ ] Buscar por descripción
   - [ ] Buscar texto que aparezca dentro de las filas
3. Verifica que los resultados se filtren correctamente

#### 4.2 Búsqueda Avanzada
1. Haz clic en el ícono de filtro para activar búsqueda avanzada
2. Prueba:
   - [ ] Filtro por fecha de creación (desde/hasta)
   - [ ] Filtro por número de filas (mínimo/máximo)
   - [ ] Limpiar filtros
3. Verifica que los filtros funcionen correctamente

---

### **FASE 5: Archivos** (5-10 minutos)

#### 5.1 Visualización
1. Abre un catálogo con filas que tengan archivos asociados
2. Para cada tipo de archivo:

   **Imágenes:**
   - [ ] Haz clic en el botón de imagen
   - [ ] Verifica que se abra el visor
   - [ ] Prueba hacer zoom (pinch)

   **PDFs:**
   - [ ] Haz clic en el botón de documento (PDF)
   - [ ] Verifica que se muestre el visor de PDF
   - [ ] Navega las páginas del PDF

   **Videos:**
   - [ ] Haz clic en el botón de multimedia
   - [ ] Verifica que se reproduzca el video
   - [ ] Prueba los controles de reproducción

#### 5.2 Exportación
1. Abre un catálogo
2. Haz clic en el menú de exportar (3 puntos o botón de exportar)
3. Prueba:
   - [ ] Exportar a CSV
   - [ ] Exportar a Excel
4. Verifica:
   - [ ] Los archivos se generan correctamente
   - [ ] Los archivos contienen todos los datos
   - [ ] Puedes abrir los archivos exportados

---

## 🐛 Problemas Comunes y Soluciones

### La app no inicia
- Verifica que todas las dependencias estén instaladas: `flutter pub get`
- Verifica que el archivo `.env` exista y tenga las configuraciones correctas
- Revisa los logs de error en la consola

### Modo offline no se activa
- Verifica que `connectivity_plus` esté instalado: `flutter pub get`
- En iOS/Android, verifica permisos de red
- Revisa los logs para ver mensajes de conectividad

### Las operaciones offline no se sincronizan
- Verifica que tengas conexión activa
- Presiona manualmente el botón de sincronización
- Revisa los logs en la consola para errores de sincronización

### La validación no aparece
- Verifica que uses `TextFormField` (no `TextField`)
- Verifica que tenga un `validator` asignado
- Verifica que el `Form` tenga un `GlobalKey<FormState>`

### Los archivos no se cargan
- Verifica las credenciales de S3 en el `.env`
- Verifica que los archivos existan en S3
- Revisa los logs para errores de carga

---

## ✅ Checklist Final

Usa el archivo `CHECKLIST_PRUEBAS.md` para marcar cada prueba completada.

### Resumen de Funcionalidades a Probar:

- [ ] Validación de datos (todos los formularios)
- [ ] Modo offline (crear/editar/eliminar sin conexión)
- [ ] Sincronización (automática y manual)
- [ ] Paginación (catálogos y filas)
- [ ] Búsqueda (simple y avanzada)
- [ ] Visualización de archivos (imágenes, PDFs, videos)
- [ ] Exportación (CSV y Excel)
- [ ] Indicadores visuales (offline, loading)

---

## 📝 Reportar Problemas

Si encuentras algún problema:

1. **Anota el problema:** qué estabas haciendo, qué esperabas, qué pasó
2. **Captura de pantalla:** si es posible, toma capturas
3. **Logs:** copia los mensajes de error de la consola
4. **Reproducir:** intenta reproducir el problema varias veces

---

## 🎉 ¡Listo para Probar!

Una vez completadas todas las pruebas, el proyecto estará listo para continuar con nuevas funcionalidades o mejoras.

