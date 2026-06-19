# 🧪 Guía de Pruebas - EDFCatalogoMultiplatform

## 📋 Funcionalidades Implementadas para Probar

### 1️⃣ **Validación de Datos**

#### Registro de Usuario
- ✅ Abre la pantalla de registro
- ✅ Intenta crear una cuenta con:
  - Username inválido (menos de 3 caracteres o caracteres especiales)
  - Email sin formato válido
  - Contraseña con menos de 6 caracteres
  - Contraseñas que no coinciden
- ✅ Verifica que aparezcan mensajes de error apropiados
- ✅ Verifica que la validación ocurre en tiempo real (mientras escribes)

#### Recuperación de Contraseña
- ✅ Ve a "Olvidé mi contraseña"
- ✅ Intenta ingresar un email inválido
- ✅ Verifica que se muestre error de validación
- ✅ Ingresa un email válido y verifica que se envíe el código

#### Restablecimiento de Contraseña
- ✅ Ingresa un código de menos de 6 dígitos
- ✅ Ingresa una contraseña corta (menos de 6 caracteres)
- ✅ Ingresa contraseñas que no coincidan
- ✅ Verifica mensajes de error apropiados

#### Añadir/Editar Filas de Catálogo
- ✅ Abre un catálogo y entra en modo edición
- ✅ Intenta añadir una fila sin completar campos requeridos
- ✅ Verifica que aparezcan mensajes de validación

---

### 2️⃣ **Modo Offline**

#### Prueba Básica de Modo Offline
1. **Conectar a internet:**
   - Abre la app y carga algunos catálogos
   - Verifica que se carguen correctamente

2. **Desconectar internet:**
   - Desactiva WiFi/Datos móviles
   - Verifica que aparezca el indicador "Modo offline" en la parte superior
   - Los catálogos existentes deberían seguir visibles

3. **Operaciones offline:**
   - Crea un nuevo catálogo (debería guardarse localmente)
   - Edita un catálogo existente
   - Elimina un catálogo
   - Verifica que estas operaciones funcionen sin conexión

4. **Reconectar:**
   - Activa WiFi/Datos móviles nuevamente
   - Presiona el botón de sincronización (ícono de sincronizar)
   - Verifica que las operaciones pendientes se sincronicen
   - Verifica que el indicador "Modo offline" desaparezca

#### Prueba de Cola de Sincronización
1. Crea varios catálogos offline
2. Edita algunos catálogos offline
3. Elimina un catálogo offline
4. Reconecta y sincroniza
5. Verifica que todas las operaciones se hayan aplicado en el servidor

---

### 3️⃣ **Paginación**

#### Lista de Catálogos
1. Si tienes más de 20 catálogos:
   - Verifica que se muestre información de paginación (ej: "1-20 de 50")
   - Navega entre páginas con los botones
   - Verifica que se muestren diferentes catálogos en cada página

2. **Infinite Scroll:**
   - Desplázate hacia abajo en la lista
   - Al llegar al final (90%), debería aparecer un botón "Cargar más"
   - Presiona el botón y verifica que se carguen más elementos

#### Filas de Catálogo
1. Abre un catálogo con más de 50 filas
2. Verifica que se muestre información de paginación
3. Navega entre páginas con los botones anterior/siguiente
4. Verifica que el ordenamiento funcione correctamente con la paginación

---

### 4️⃣ **Búsqueda Avanzada**

1. Abre la vista de catálogos
2. Haz clic en el ícono de filtro para activar búsqueda avanzada
3. Prueba los filtros:
   - Filtro por fecha de creación
   - Filtro por número de filas (mínimo/máximo)
4. Verifica que los resultados se filtren correctamente
5. Limpia los filtros y verifica que se restauren todos los catálogos

---

### 5️⃣ **Visualizador de Archivos**

1. Abre un catálogo con filas que tengan archivos asociados
2. Haz clic en los botones de archivos (Imagen, Documento, Multimedia)
3. Verifica:
   - **Imágenes**: Se cargan y se puede hacer zoom
   - **PDFs**: Se muestran correctamente con el visor
   - **Videos**: Se reproducen con controles
4. Prueba el botón "Abrir en navegador" para archivos no soportados

---

### 6️⃣ **Exportación de Datos**

1. Abre un catálogo
2. Haz clic en el botón de exportar (menú de 3 puntos)
3. Prueba:
   - Exportar a CSV
   - Exportar a Excel
4. Verifica que los archivos se generen correctamente
5. Abre los archivos exportados y verifica que contengan todos los datos

---

## 🔍 Verificación de Errores Comunes

### Errores de Compilación
```bash
# Verifica errores
flutter analyze

# Verifica que todo compile
flutter build [platform]
```

### Errores en Runtime
1. Revisa la consola para mensajes de error
2. Verifica que todas las variables de entorno estén configuradas (`.env`)
3. Verifica la conexión a MongoDB
4. Verifica las credenciales de AWS S3 (si se usan)

---

## 📝 Checklist de Pruebas

- [ ] Validación funciona en todos los formularios
- [ ] Modo offline se activa correctamente
- [ ] Operaciones offline se guardan localmente
- [ ] Sincronización funciona al reconectar
- [ ] Paginación funciona en listas y filas
- [ ] Búsqueda avanzada filtra correctamente
- [ ] Visualizador muestra todos los tipos de archivo
- [ ] Exportación genera archivos válidos
- [ ] Indicadores de estado (offline, loading) son visibles
- [ ] Mensajes de error son claros y útiles

---

## 🐛 Problemas Conocidos y Soluciones

### El modo offline no se activa
- Verifica que `connectivity_plus` esté instalado: `flutter pub get`
- Verifica permisos de red en la plataforma

### Las operaciones offline no se sincronizan
- Verifica que haya conexión activa
- Presiona manualmente el botón de sincronización
- Revisa los logs en la consola

### La validación no aparece
- Verifica que los campos usen `TextFormField` (no `TextField`)
- Verifica que tengan un `validator` asignado
- Verifica que el `Form` tenga un `GlobalKey<FormState>`

---

## 🚀 Próximos Pasos Después de Probar

Una vez que hayas probado las funcionalidades, puedes:
1. Reportar bugs o problemas
2. Solicitar mejoras o ajustes
3. Continuar con nuevas funcionalidades (compartir, colaboración, etc.)

