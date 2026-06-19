# ✅ Checklist de Pruebas Rápido

## 🚀 Preparación

- [ ] Ejecutar `flutter pub get` para instalar dependencias
- [ ] Verificar que el archivo `.env` existe y tiene las configuraciones necesarias
- [ ] Ejecutar `flutter analyze` para verificar errores
- [ ] Ejecutar `flutter run` para iniciar la aplicación

---

## 📋 Validación de Datos

### Registro

- [ ] Campo username: muestra error si < 3 caracteres
- [ ] Campo username: muestra error si tiene caracteres especiales
- [ ] Campo email: muestra error si no tiene formato válido
- [ ] Campo contraseña: muestra error si < 6 caracteres
- [ ] Campo confirmar contraseña: muestra error si no coincide
- [ ] Validación ocurre en tiempo real (mientras escribes)

### Recuperación de Contraseña

- [ ] Campo email: muestra error si formato inválido
- [ ] Permite enviar código si email es válido

### Restablecimiento de Contraseña

- [ ] Campo código: muestra error si no tiene 6 dígitos
- [ ] Campo nueva contraseña: muestra error si < 6 caracteres
- [ ] Campo confirmar: muestra error si no coincide

### Añadir/Editar Filas

- [ ] Campos requeridos muestran error si están vacíos
- [ ] Validación aparece en tiempo real

---

## 📴 Modo Offline

### Activación de Modo Offline

- [ ] Al desactivar WiFi/datos, aparece indicador "Modo offline"
- [ ] Los catálogos existentes siguen visibles
- [ ] Aparece botón de sincronización

### Operaciones Offline

- [ ] ✅ Crear catálogo funciona sin conexión
- [ ] ✅ Editar catálogo funciona sin conexión
- [ ] ✅ Eliminar catálogo funciona sin conexión
- [ ] ✅ Añadir filas funciona sin conexión
- [ ] ✅ Editar filas funciona sin conexión

### Sincronización

- [ ] Al reconectar, las operaciones se sincronizan automáticamente
- [ ] Botón de sincronización manual funciona
- [ ] Las operaciones se aplican correctamente en el servidor
- [ ] El indicador "Modo offline" desaparece al reconectar

---

## 📄 Paginación

### Lista de Catálogos

- [ ] Si hay > 20 catálogos, muestra información de paginación
- [ ] Navegación entre páginas funciona
- [ ] Botón "Cargar más" aparece al final
- [ ] Se cargan más elementos al presionar "Cargar más"

### Filas de Catálogo

- [ ] Si hay > 50 filas, muestra información de paginación
- [ ] Navegación entre páginas funciona
- [ ] El ordenamiento funciona con la paginación

---

## 🔍 Búsqueda

### Búsqueda Simple

- [ ] Busca por nombre de catálogo
- [ ] Busca por descripción
- [ ] Busca dentro de las filas

### Búsqueda Avanzada

- [ ] Filtro por fecha funciona
- [ ] Filtro por número de filas funciona
- [ ] Limpiar filtros funciona

---

## 📁 Archivos

### Visualización

- [ ] ✅ Imágenes se cargan correctamente
- [ ] ✅ PDFs se visualizan correctamente
- [ ] ✅ Videos se reproducen correctamente
- [ ] Botón "Abrir en navegador" funciona

### Exportación

- [ ] Exportar a CSV funciona
- [ ] Exportar a Excel funciona
- [ ] Los archivos exportados contienen todos los datos

---

## 🐛 Errores Comunes a Verificar

- [ ] No hay errores en la consola al iniciar
- [ ] Las conexiones a MongoDB funcionan
- [ ] Las conexiones a S3 funcionan
- [ ] Los mensajes de error son claros y útiles
- [ ] Los indicadores de carga aparecen cuando corresponden

---

## 📝 Notas

__Fecha de pruebas:__ ________________

__Dispositivo/Plataforma:__ ________________

__Versión de Flutter:__ ________________

**Observaciones:**

---

---

---

