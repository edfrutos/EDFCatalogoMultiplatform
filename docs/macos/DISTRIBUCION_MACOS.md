# Distribución macOS — Developer ID + Notarización

> **Estado:** ✅ **DMG notarizado y grapado funcionando** — `EDFCatalogo-1.2.0.dmg`,
> `spctl → accepted, source=Notarized Developer ID`. Pipeline completo en `build_macos_dmg.sh`.
> Pendiente: probar conexión MongoDB en la build notarizada, commitear, limpieza `Info.plist`.
> **Última actualización:** 2026-09-03

### Datos del proyecto

| Dato | Valor |
|---|---|
| **Apple Team ID** | `V29BTBRY6G` |
| Certificados instalados | *Developer ID Application* ✅ · *Developer ID Installer* ✅ (este último solo para `.pkg`/MAS futuro) |
| Canal de distribución | **Intranet** (decisión §5, opción A) — el DMG no se publica fuera de la organización |
| Bundle ID | `com.edfcatalogo.edfcatalogomultiplatform` |
| Toolchain | Xcode **27 beta** (migración en curso desde 26) — Flutter subió el *deployment target* a **macOS 12.0** y regeneró `Podfile` + `project.pbxproj` |

### Progreso

- ✅ `scripts/build_macos_dmg.sh` refactorizado: modo `--adhoc` (histórico, por defecto sin identidad)
  y modo Developer ID (Hardened Runtime + firma del DMG + `notarytool` + `stapler`). El script
  **autoresuelve** el certificado *Developer ID Application* a partir de `APPLE_TEAM_ID`
  (no hace falta escribir la identidad completa). Flags: `--adhoc`, `--identity`, `--skip-notarize`.
- ✅ `.env.example`: `APPLE_TEAM_ID=V29BTBRY6G`, `NOTARY_PROFILE=edf-notary`, `MACOS_SIGN_IDENTITY` (override opcional, vacío).
- ✅ `pubspec.yaml` alineado a `1.2.0+3`.
- ✅ `macos/Flutter/Flutter-Release.xcconfig`: comentario actualizado (revalidar en cada Xcode beta).
- ⏳ Pendiente (requiere Mac): `xcrun notarytool store-credentials "edf-notary"`, limpieza de
  `Info.plist`, entitlements de Hardened Runtime, commit de `packages/edfcatalogo_crypto`,
  consolidar migración Xcode 27 beta del `.pbxproj`/`.xcscheme`.

---

## 1. Perspectiva y alcance

### 1.1 Objetivo inmediato

Pasar de la **firma ad-hoc actual** (`codesign --sign -`, sin identidad) a una app
**firmada con Developer ID Application + notarizada por Apple + con el ticket "stapled"**,
distribuida **fuera de la Mac App Store** en un DMG descargable.

Resultado esperado: el usuario final abre `EDF Catálogo.app` con **doble clic normal**,
sin pasar por *Ajustes del Sistema → Privacidad y Seguridad → Abrir de todas formas*,
en cualquier Mac con conexión a Internet (Gatekeeper valida el ticket online y offline
una vez grapado).

### 1.2 Qué NO se hace ahora

- **No** se publica en la Mac App Store (MAS).
- **No** se crean registros en App Store Connect, ni `Distribution` provisioning profiles,
  ni `App Sandbox` con los entitlements adicionales que MAS exige.
- **No** se aplica `PrivacyInfo.xcprivacy` propio del target, ni el cuestionario de
  privacidad de MAS, ni `ITSAppUsesNonExemptEncryption`.

### 1.3 Por qué este orden

| Motivo | Detalle |
|---|---|
| **Menor superficie de fricción** | Developer ID + notarización no pasa revisión humana de Apple; el ciclo es minutos, no días. |
| **La arquitectura actual encaja** | El cliente nativo habla directo con MongoDB Atlas / S3. MAS penaliza (aunque no prohíbe) este patrón y exige justificar accesos de red y ficheros. Fuera de MAS no hay revisor. |
| **Permite iterar el instalador** | Se puede publicar y actualizar el DMG sin depender de tiempos de Apple. |
| **No cierra la puerta a MAS** | Ver §6: las decisiones que se toman ahora se eligen para que MAS siga siendo viable más adelante con trabajo incremental, no con un rediseño. |

---

## 2. Situación de partida (auditoría)

| Elemento | Estado actual | Necesario para Developer ID + notarización |
|---|---|---|
| Firma | Ad-hoc (`codesign --sign -`) en `scripts/build_macos_dmg.sh` | **Developer ID Application: <NOMBRE> (<TEAM_ID>)** |
| Hardened Runtime | ❌ No se aplica (`--options runtime` ausente) | ✅ Obligatorio para notarizar |
| Entitlements | `macos/Runner/Release.entitlements` — sandbox ON, sin claves `com.apple.security.cs.*` | Añadir excepciones de runtime que exijan los plugins (ver §4.2) |
| Notarización | ❌ Inexistente (no hay `notarytool` ni `stapler` en scripts) | ✅ `xcrun notarytool submit --wait` + `xcrun stapler staple` |
| `Info.plist` (macOS) | `NSAllowsArbitraryLoads = true`; claves de *entitlement* mal colocadas; sin `NSUsageDescription`; sin `LSApplicationCategoryType` | Limpiar (ver §4.3) |
| Secretos | `.env` empaquetado como asset del bundle (`pubspec.yaml → flutter/assets`) con credenciales Atlas + AWS + Brevo | Mitigar antes de publicar (ver §5) |
| Versión | ~~`pubspec.yaml` = `1.1.0+2`~~ → **`1.2.0+3`** ✅ | Subir `+N` en cada entrega |
| CI | Solo `ubuntu-latest` (Web + Android) | Job opcional `macos-latest` (ver §7 fase 5) |
| `packages/edfcatalogo_crypto` | Sin trackear en git; el build ya depende de él | Commitear antes de tocar el pipeline de release |
| Toolchain Xcode | Migración **26 → 27 beta** en curso (cambios en `.pbxproj` / `.xcscheme` sin commitear) | Consolidar y revalidar `CODE_SIGNING_ALLOWED=NO` + build release |

---

## 3. Prerrequisitos (cuenta y credenciales Apple)

1. ✅ **Apple Developer Program** activo. **Team ID: `V29BTBRY6G`**.
2. ✅ **Certificados instalados** en el llavero del Mac de build:
   - *Developer ID Application* — firma la app y el DMG (lo que usa este flujo).
   - *Developer ID Installer* — firma paquetes `.pkg`; no se usa en distribución por DMG,
     queda disponible para un instalador `.pkg` o para trabajo MAS futuro.
   - Verificar: `security find-identity -v -p codesigning` debe listar
     `"Developer ID Application: <NOMBRE> (V29BTBRY6G)"`.
3. ⏳ **Perfil de credenciales para `notarytool`** (evita meter la contraseña en cada llamada).
   Requiere una **contraseña específica de app** (App-Specific Password) creada en
   <https://account.apple.com> → *Iniciar sesión y seguridad → Contraseñas de apps*:
   ```bash
   xcrun notarytool store-credentials "edf-notary" \
     --apple-id "TU_APPLE_ID@ejemplo.com" \
     --team-id "V29BTBRY6G" \
     --password "xxxx-xxxx-xxxx-xxxx"   # App-Specific Password
   ```
   Esto guarda el perfil `edf-notary` en el llavero. El script lo lee vía `NOTARY_PROFILE=edf-notary`.

> **Alternativa CI (sin llavero interactivo):** API Key de App Store Connect
> (`AuthKey_XXXX.p8` + Key ID + Issuer ID). Se usa con
> `notarytool submit --key … --key-id … --issuer …`. Ver §7 fase 5.

### 3.1 Variables / secretos que se usarán

| Nombre | Dónde | Uso |
|---|---|---|
| `APPLE_TEAM_ID` | `.env` (`V29BTBRY6G`) / secret CI | El script autoresuelve el cert *Developer ID Application* de ese Team |
| `MACOS_SIGN_IDENTITY` | `.env` / secret CI — **override opcional, normalmente vacío** | Fuerza una identidad concreta si la autoresolución no vale |
| `NOTARY_PROFILE` | Solo local (`edf-notary`) | Perfil de llavero de `notarytool` |
| `MACOS_CERT_P12_BASE64` + `MACOS_CERT_PASSWORD` | Solo secret CI | Importar el cert en el runner |
| `NOTARY_API_KEY` (ruta `.p8`) + `NOTARY_API_KEY_ID` + `NOTARY_API_ISSUER` | Solo secret CI | Notarizar sin llavero |

`.env.example` ya incluye `APPLE_TEAM_ID` y `NOTARY_PROFILE` con los valores reales (no son secretos).

---

## 4. Cambios en el repositorio

### 4.1 `scripts/build_macos_dmg.sh` — pipeline de firma ✅ implementado

Flujo parametrizado (ya en el script):

```
1. Resolver identidad:
   - --adhoc                               → firma ad-hoc (comportamiento histórico)
   - $MACOS_SIGN_IDENTITY / --identity      → esa identidad exacta
   - solo $APPLE_TEAM_ID                     → autoresuelve el cert "Developer ID Application"
                                              de ese Team vía `security find-identity`
   - nada de lo anterior                     → firma ad-hoc

2. Firmar inside-out CON hardened runtime cuando la identidad es real:
   codesign --force --options runtime --timestamp \
            --entitlements macos/Runner/Release.entitlements \
            --sign "$MACOS_SIGN_IDENTITY" <cada componente> ... <bundle .app>
   (el orden dylibs → frameworks → binario → .app ya es correcto en el script)

3. Verificar firma:
   codesign --verify --deep --strict --verbose=2 "<APP>"
   spctl -a -vvv -t exec "<APP>"        # debe decir "accepted / Developer ID" (falla hasta notarizar: normal)

4. Construir el DMG (igual que ahora: create → attach → ditto → detach → convert UDZO)

5. Firmar el DMG:
   codesign --force --sign "$MACOS_SIGN_IDENTITY" --timestamp "<DMG>"

6. Notarizar (solo si identidad real y no --skip-notarize):
   xcrun notarytool submit "<DMG>" --keychain-profile "$NOTARY_PROFILE" --wait
   → si "Accepted": xcrun stapler staple "<DMG>"
                    (y opcionalmente re-staple del .app antes de empaquetar)
   → si "Invalid":  xcrun notarytool log <submission-id> --keychain-profile "$NOTARY_PROFILE"

7. Validar el resultado final:
   xcrun stapler validate "<DMG>"
   spctl -a -vvv -t install "<DMG>"
```

Flags del script: `--adhoc` (fuerza modo interno), `--identity "…"` (override),
`--skip-notarize` (firma Developer ID sin enviar a notarizar). El modo ad-hoc se
mantiene como fallback para builds internos rápidos.

Credenciales de notarización: `NOTARY_PROFILE` (perfil de llavero) o, para CI,
`NOTARY_API_KEY` + `NOTARY_API_KEY_ID` + `NOTARY_API_ISSUER`. Si faltan, el script
firma pero avisa y omite la notarización.

### 4.2 `macos/Runner/Release.entitlements` — Hardened Runtime

El sandbox ya está activo. La notarización con hardened runtime puede requerir excepciones
según los plugins nativos. Plugins macOS presentes (de `GeneratedPluginRegistrant.swift` /
`Podfile.lock`): `media_kit_video` + `media_kit_libs_macos_video`, `video_player_avfoundation`,
`webview_flutter_wkwebview`, `syncfusion_pdfviewer_macos`, `flutter_secure_storage_macos`,
`file_picker`, `file_selector_macos`, `share_plus`, `path_provider_foundation`,
`url_launcher_macos`, `connectivity_plus`, `device_info_plus`, `package_info_plus`,
`sqflite_darwin`, `volume_controller`, `wakelock_plus`.

Punto de partida (añadir solo lo que el build/arranque demuestre necesario — **no** añadir a ciegas):

```xml
<!-- Ya presentes -->
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
<key>com.apple.security.files.downloads.read-write</key><true/>

<!-- Candidatos Hardened Runtime — validar uno a uno -->
<!-- media_kit / FFmpeg suele necesitar memoria ejecutable no firmada por nosotros: -->
<key>com.apple.security.cs.disable-library-validation</key><true/>
<!-- Solo si el arranque falla con dylibs de plugins: -->
<!-- <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/> -->
<!-- <key>com.apple.security.cs.allow-jit</key><true/> -->
```

> **`com.apple.security.network.server`**: hoy está en `Release.entitlements` y en
> `DebugProfile.entitlements`. Un cliente no necesita escuchar conexiones entrantes.
> Revisar si algún plugin (webview local, media_kit) lo requiere; si no, **quitarlo**
> (además es una de las claves que MAS mira con lupa — ver §6).

Método de validación: build → firmar → `open EDF\ Catálogo.app` desde `/Applications` en
un Mac limpio (o segunda cuenta) → ejercitar: login, subir imagen (S3), abrir PDF, reproducir
vídeo local, reproducir YouTube, backup a Drive, export CSV. Cualquier crash con
`EXC_BAD_ACCESS` / `code signature invalid` → añadir la excepción correspondiente y re-firmar.

### 4.3 `macos/Runner/Info.plist` — limpieza

```
- Eliminar   NSAppTransportSecurity → NSAllowsArbitraryLoads = true
             (usar HTTPS en todo; si algún endpoint sigue en HTTP, poner excepción por dominio)
- Eliminar   com.apple.security.network.client / .network.server
             (son entitlements, no van en Info.plist — hoy están mal colocados)
+ Añadir     LSApplicationCategoryType = public.app-category.productivity
+ Añadir     NSUsageDescription según lo que se ejercite en runtime:
               NSCameraUsageDescription        (si image_picker abre cámara)
               NSMicrophoneUsageDescription    (si media_kit / video captura audio)
               NSDownloadsFolderUsageDescription / NSDocumentsFolderUsageDescription
               NSPhotoLibraryUsageDescription  (si aplica)
             (iOS ya las tiene en ios/Runner/Info.plist — reutilizar textos)
```

Estas excepciones y textos son **también** los que MAS pediría, así que el trabajo no se
tira: adelanta la fase MAS.

### 4.4 Versionado

- Alinear `pubspec.yaml` con el estado real (`1.2.0+N`).
- Cada entrega sube `+N` (`--build-number`), que Xcode mapea a `CFBundleVersion`.
- `scripts/build_macos_dmg.sh` ya deriva `VERSION` de `pubspec.yaml` para el nombre del DMG.

### 4.5 `packages/edfcatalogo_crypto`

Está sin trackear y el build macOS ya lo importa (`s3_service.dart`). **Commitearlo con sus
tests antes** de tocar el pipeline de release, para que `flutter build macos --release`
sea reproducible desde un clon limpio.

---

## 5. Secretos en el bundle (condición para publicar fuera de la intranet)

`pubspec.yaml` incluye `.env` en `flutter/assets`. En la app distribuida eso expone, con un
simple `unzip EDF\ Catálogo.app`:

- `MONGO_URI` (usuario + contraseña de MongoDB Atlas)
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- API key de Brevo, credenciales OAuth de Google Drive

Ya hubo un incidente por esto (`docs/misc/SECURITY_INCIDENT.md`). **La notarización no
protege el contenido del bundle** — solo garantiza origen e integridad. Opciones, de menor
a mayor esfuerzo:

| Opción | Esfuerzo | Resultado |
|---|---|---|
| **A. Distribución solo intranet** | 0 | Aceptable si el DMG no sale de la organización. Documentarlo explícitamente. |
| **B. Endurecer credenciales** | Bajo | Usuario Atlas de mínimos privilegios + IP allowlist; credenciales AWS temporales (STS) o usuario IAM restringido a `PutObject`/`GetObject` del bucket. Reduce el daño, no lo elimina. |
| **C. Enrutar el cliente por la API Dart** | Medio-Alto | El nativo deja de llevar credenciales; usa `ApiService` como ya hace Web. Es el estado final deseable y **el que MAS espera**. |

**Decisión tomada (2026-09-03): opción A.** La primera entrega notarizada es de
**uso interno / intranet**: el DMG no se publica en web pública ni en releases abiertas.
Implicaciones operativas:

- El DMG se comparte solo por canal controlado (unidad compartida, correo interno, repo privado).
- `README.md` y las notas de versión deben indicar "distribución interna".
- **B** (endurecer credenciales Atlas/AWS) y **C** (cliente vía API Dart) quedan como mejoras
  posteriores; son requisito antes de cualquier distribución pública o de plantear MAS.
- Rotar de todas formas las credenciales que hayan estado en `.env` versionado en el histórico.

---

## 6. Decisiones que mantienen viable la Mac App Store

No se hace trabajo MAS ahora, pero se evita cerrar la puerta:

| Decisión ahora | Por qué preserva MAS |
|---|---|
| **Mantener `com.apple.security.app-sandbox = true`** | MAS lo exige. Salir del sandbox ahora obligaría a re-auditar toda la app después. |
| **Entitlements mínimos y justificados** (quitar `network.server` si no se usa; documentar cada `com.apple.security.cs.*`) | MAS revisa cada entitlement. Menos excepciones = revisión más sencilla luego. |
| **`Info.plist` limpio + `NSUsageDescription` reales** (§4.3) | Es requisito MAS; hacerlo ahora es adelantar trabajo. |
| **`LSApplicationCategoryType` definido** | Requisito MAS. |
| **Bundle ID estable** `com.edfcatalogo.edfcatalogomultiplatform` | Cambiarlo después rompe la identidad del producto y complica el alta en App Store Connect. Fijarlo ya. |
| **No usar APIs privadas ni binarios sin firmar de origen dudoso** | Rechazo automático en MAS. El pipeline de firma inside-out ya firma todo. |
| **Objetivo arquitectónico "C" (API proxy) registrado** | El día que se quiera MAS, el cambio grande (sacar credenciales del cliente) ya está identificado y a medio camino. |
| **No depender de `Sparkle` para autoactualización dentro del código que iría a MAS** | MAS no permite autoactualizadores. Si se añade Sparkle (§8), aislarlo tras un flag de build `MACOS_CHANNEL=directo` para poder compilar una variante MAS sin él. |

**Trabajo que MAS añadiría (pendiente, no ahora):** cuenta App Store Connect + ficha,
certificado `Apple Distribution` + `Mac App Distribution` + provisioning profile,
`PrivacyInfo.xcprivacy` del target, cuestionario de privacidad, `ITSAppUsesNonExemptEncryption`,
revisión de que todos los accesos a ficheros pasan por *powerbox* (file pickers, no rutas
hardcoded), y `pkgbuild`/`productbuild` firmado con `3rd Party Mac Developer Installer` en
lugar de DMG.

---

## 7. Plan de ejecución por fases

### Fase 0 — Higiene previa (sin cuenta Apple)
- [ ] Commitear `packages/edfcatalogo_crypto` con sus tests.
- [ ] Consolidar la migración **Xcode 27 beta** del `.pbxproj` / `.xcscheme` (en curso, sin commitear).
      Revalidar `CODE_SIGNING_ALLOWED = NO` en `Flutter-Release.xcconfig` y que
      `flutter build macos --release` sigue OK con la nueva toolchain.
- [x] Alinear versión en `pubspec.yaml` → `1.2.0+3`.
- [ ] `flutter build macos --release` reproducible desde clon limpio.

### Fase 1 — Preparar el proyecto (sin cuenta Apple) ✅ se puede hacer ya
- [x] Refactor `scripts/build_macos_dmg.sh`: identidad parametrizada, modo `--adhoc` explícito, notarización tras guard de identidad.
- [x] Ampliar `.env.example` con `APPLE_TEAM_ID`, `MACOS_SIGN_IDENTITY`, `NOTARY_PROFILE`.
- [ ] Verificar en un Mac que `--adhoc` produce el mismo DMG que antes (sin regresión).
- [ ] Limpiar `macos/Runner/Info.plist` (§4.3).
- [ ] Añadir `LSApplicationCategoryType` y `NSUsageDescription`.
- [ ] Crear variante de `Release.entitlements` con candidatos de Hardened Runtime comentados (§4.2).

### Fase 2 — Primera firma real (Team ID `V29BTBRY6G`)
- [x] Apple Developer Program activo; Team ID conocido.
- [x] Certs *Developer ID Application* + *Developer ID Installer* instalados.
- [ ] `xcrun notarytool store-credentials "edf-notary" --apple-id … --team-id V29BTBRY6G --password APP_SPECIFIC_PW`.
- [ ] `cp .env.example .env` (o actualizar el `.env` existente): `APPLE_TEAM_ID=V29BTBRY6G`, `NOTARY_PROFILE=edf-notary`.
- [ ] `./scripts/build_macos_dmg.sh` → autoresuelve la identidad, firma con Hardened Runtime.
- [ ] Resolver iterativamente entitlements de runtime hasta que la app arranque y pase el smoke test (§4.2).
- [ ] Comparar antes: `./scripts/build_macos_dmg.sh --adhoc` debe seguir generando el DMG interno sin regresión.

### Fase 3 — Notarización ✅
- [x] `notarytool submit --wait` → `status: Accepted` (id `5eebe76d-3da9-4a3a-85b1-73f4d7ea5606`).
- [x] `stapler staple` + `stapler validate` → OK.
- [x] `spctl -a -t install` → `accepted`, `source=Notarized Developer ID`.
- [ ] Prueba en **Mac limpio / segunda cuenta**: doble clic sin advertencia + **conexión MongoDB OK**.

### Fase 4 — Publicación (interna, §5 opción A)
- [ ] Subir el DMG al **canal interno** (unidad compartida / repo privado). **No** web pública ni releases abiertas.
- [ ] Publicar checksum SHA-256 y notas de versión ("distribución interna").
- [x] Actualizar `README.md` §"macOS — distribuible (DMG)" con los dos modos.
- [ ] Actualizar `docs/arquitectura.md` §9.1 y §11 (nueva entrada de versión).

### Fase 5 — CI (opcional, recomendable)
- [ ] Job `build-macos` en `macos-latest`: importar cert desde `MACOS_CERT_P12_BASE64`,
      `flutter build macos --release`, firmar, notarizar con **API Key** de App Store Connect
      (`NOTARY_API_KEY_P8_BASE64` / `_ID` / `_ISSUER`), `stapler`, subir el DMG como artefacto.
- [ ] Gate de verificación: `codesign --verify --deep --strict` + `spctl` + `stapler validate`.

### Fase 6 — Endurecimiento de credenciales (paralelo, §5 opción B)
- [ ] Usuario Atlas de mínimos + IP allowlist.
- [ ] Credenciales AWS restringidas al bucket / STS temporal.
- [ ] Rotar las credenciales que hoy están en el `.env` versionado históricamente.

---

## 8. Autoactualización (fuera de alcance inicial, nota de diseño)

Sin MAS, no hay actualización automática. Si más adelante se añade **Sparkle**:

- El appcast (feed XML firmado con EdDSA) y el binario de Sparkle deben quedar **tras un
  flag de build** (`MACOS_CHANNEL`), para poder compilar una variante sin Sparkle el día
  que se quiera MAS.
- Requiere alojar el appcast en HTTPS con dominio propio.

Hasta entonces: el usuario descarga el nuevo DMG manualmente. La app puede mostrar un aviso
"hay versión nueva" comparando `CFBundleVersion` contra un JSON público (sin autoinstalar).

---

## 9. Comandos de referencia

```bash
# Identidades de firma disponibles
security find-identity -v -p codesigning

# Firmar un componente con hardened runtime
codesign --force --options runtime --timestamp \
  --entitlements macos/Runner/Release.entitlements \
  --sign "Developer ID Application: NOMBRE (TEAMID)" "ruta/al/componente"

# Verificar firma del .app
codesign --verify --deep --strict --verbose=2 "build/macos/Build/Products/Release/EDF Catálogo.app"
codesign -dvvv --entitlements :- "build/macos/Build/Products/Release/EDF Catálogo.app"

# Evaluación Gatekeeper (antes de notarizar: rechazará; es lo esperado)
spctl -a -vvv -t exec "build/macos/Build/Products/Release/EDF Catálogo.app"

# Notarizar (perfil de llavero)
xcrun notarytool submit "dist/EDFCatalogo-1.2.0.dmg" --keychain-profile "edf-notary" --wait

# Ver el log de una notarización fallida
xcrun notarytool log <submission-id> --keychain-profile "edf-notary"

# Grapar el ticket
xcrun stapler staple "dist/EDFCatalogo-1.2.0.dmg"
xcrun stapler validate "dist/EDFCatalogo-1.2.0.dmg"

# Evaluación final (tras staple)
spctl -a -vvv -t install "dist/EDFCatalogo-1.2.0.dmg"
```

---

## 10. Criterios de "listo para distribución" (Definition of Done)

- [ ] `codesign --verify --deep --strict` sin errores sobre el `.app`.
- [ ] Firma con identidad `Developer ID Application`, no ad-hoc.
- [ ] Hardened Runtime activo (`codesign -dvvv` muestra `flags=0x10000(runtime)`).
- [ ] `notarytool submit` → `status: Accepted`.
- [ ] `stapler validate` OK sobre `.app` y `.dmg`.
- [ ] `spctl -a -t install` sobre el DMG → `accepted`, `source=Notarized Developer ID`.
- [ ] Apertura con doble clic en un Mac limpio sin advertencia de Gatekeeper.
- [ ] Smoke test funcional completo (login, S3, PDF, vídeo, YouTube, Drive, export).
- [ ] `pubspec.yaml` versionado y `CFBundleVersion` incrementado.
- [ ] Decisión §5 tomada y documentada (intranet vs. credenciales endurecidas vs. API proxy).
- [ ] `README.md` y `docs/arquitectura.md` actualizados.

---

## A. Troubleshooting — `codesign` falla bajo Xcode 27 beta (2026-09-03)

### Síntomas observados

Al ejecutar `./scripts/build_macos_dmg.sh --adhoc` tras migrar a Xcode 27 beta:

- `flutter build macos --release` **compila bien** (`✓ Built ... EDF Catálogo.app (115.7MB)`).
  Los `error: the following command failed with exit code 0 but produced no further output`
  de `SwiftCompile ... webview_flutter_wkwebview` son **ruido conocido** de la compilación
  Swift en paralelo con Xcode beta — no rompen el build (exit 0).
- Flutter sube el *deployment target* a **12.0** y reescribe `Podfile` (`platform :osx, '12.0'`)
  y `project.pbxproj`. Esto es esperado; hay que commitearlo.
- **El fallo real es la firma:**
  - Al firmar `Contents/MacOS/EDF Catálogo`: `code object is not signed at all` +
    `In subcomponent: .../Contents/MacOS/EDF Catálogo`.
  - Al firmar el bundle con `--deep`: **`Bus error: 10`** (crash de `codesign`).
  - Resultado: el `.app` queda **sin firmar** y el DMG se genera con una app no firmada.

### Causa probable

1. `codesign --deep` para *firmar* apps Flutter grandes provoca `Bus error` — es un uso
   incorrecto de `--deep` (solo para verificar), agravado por betas de Xcode.
2. Build **universal (arm64 + x86_64)**: Flutter avisa
   *"Xcode 27 no longer requires macOS binaries to support the x86_64 architecture"*.
   El manejo de binarios universales por el `codesign` de la beta es una fuente frecuente
   de crashes; el slice x86_64 aquí no aporta nada (toda la intranet es Apple Silicon).

### Acciones (en orden) — evolución

1. ✅ **Build solo-arm64** — `flutter config --enable-macos-arm64-only` + `flutter clean`.
   El `.app` pasó de 115 MB (universal) a **58 MB** (arm64). Desapareció el `Bus error: 10`:
   el ejecutable principal y el bundle **se firman sin crash**. Requisito cumplido: parque
   100 % Apple Silicon (Mac Studio).

2. ✅ **Script sin `--deep` para firmar** + `xattr -cr` del bundle + `error` (abort) si
   `codesign --verify` falla en modo Developer ID.

3. ✅ **No firmar el binario interno de cada `.framework`**. El script firmaba
   `X.framework/X` (symlink a `Versions/Current/X`) además del bundle → al verificar el
   `.app` salía **`a sealed resource is missing or invalid`**. Ahora solo firma el
   *framework bundle* (`codesign … X.framework`); codesign resuelve `Versions/Current`.
   Los `.dylib` sueltos se siguen firmando uno a uno.

4. ✅ **CAUSA RAÍZ del `a sealed resource is missing or invalid`**: el fichero
   **`Contents/Resources/.env` tenía modo `0700` (`-rwx------`)** — heredado del
   `.env` del repo. Un fichero **con bit de ejecución dentro de `Contents/Resources/`**
   hace que `codesign` lo trate como *código anidado* en vez de recurso, y `--verify`
   falla. (No era AppleDouble ni universal ni NFC/NFD.)
   **Fix aplicado:**
   - `macos/copy_env.sh`: copia el `.env` con `chmod 0644` + `xattr -c`.
   - `build_macos_dmg.sh` (3·0b): `find Contents/Resources -type f -exec chmod a-x` antes de firmar.
   Pendiente: reconstruir y confirmar `codesign --verify --deep --strict` **limpio**.

### Relación con el fallo de conexión a MongoDB

Un `.app` **sandboxed con firma inválida** puede hacer que el kernel **no aplique los
entitlements** (`com.apple.security.network.client`) → la app abre pero no conecta a
MongoDB/S3, o trae datos incompletos. Por eso el fix del sello es prioritario: es
probable que resuelva también ese síntoma. Verificar en paralelo:
`cat "<app>/Contents/Resources/.env" | grep -E 'MONGO_URI|MONGO_DB'` y arrancar la app
desde Terminal para ver los `⚠️ / ❌` de `main.dart`.

5. ✅ **CAUSA RAÍZ REAL confirmada (2026-09-03)**: el nombre del bundle/binario
   **"EDF Catálogo" con `á`**. En macOS 27 beta, `codesign --verify` de un `.app`
   cuyo nombre/paths contienen ese carácter (NFD/NFC) devuelve
   `a sealed resource is missing or invalid` **sin nombrar el recurso**. Test:
   copiar el `.app` firmado a `EDFCatalogo.app`, renombrar el ejecutable y re-firmar
   → `valid on disk` + `satisfies its Designated Requirement`.
   **Fix aplicado:**
   - `macos/Runner/Configs/AppInfo.xcconfig`: `PRODUCT_NAME = EDFCatalogo` (ASCII).
   - `macos/Runner/Info.plist`: `CFBundleDisplayName = EDF Catálogo` (nombre visible).
   - `.pbxproj` + `.xcscheme`: refs del producto → `EDFCatalogo.app`.
   - `build_macos_dmg.sh` / `copy_env.sh`: `EDFCatalogo.app`.
   El usuario sigue viendo "EDF Catálogo" en Finder/Dock/Acerca de.

### Diagnósticos si `--verify` sigue avisando

```bash
APP="/tmp/edf_sign_XXXX/EDF Catálogo.app"   # o el .app de build/.../Release
codesign --verify --deep --strict --verbose=4 "$APP" 2>&1 | grep -Ev '^--(prepared|validated)'
# Ver qué recurso concreto falla:
codesign -dvvv --verbose=4 "$APP" 2>&1 | tail -30
xattr -lr "$APP" | head
# ¿Crash de codesign de la beta?
ls -t ~/Library/Logs/DiagnosticReports/ | grep -i codesign | head
codesign --version ; xcode-select -p
```
Si `codesign` de Xcode 27 beta está roto: `sudo xcode-select -s /Library/Developer/CommandLineTools`
para firmar (revertir a Xcode-beta después con `sudo xcode-select -s /Applications/Xcode-beta.app`).

### Otros pendientes que abre esta migración

- `LSMinimumSystemVersion` / docs: **10.15 → 12.0**. Actualizar §2 y `README` cuando se cierre.
- `volume_controller` PrivacyInfo.xcprivacy: warning `no rule to process file` — inofensivo ahora.
- Commitear `Podfile` + `project.pbxproj` regenerados (parte de Fase 0).

---

## 11. Referencias

- Notarización: <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- `notarytool`: `xcrun notarytool --help`
- Hardened Runtime: <https://developer.apple.com/documentation/security/hardened-runtime>
- Resolución de problemas de notarización: <https://developer.apple.com/documentation/security/resolving-common-notarization-issues>
- Flutter macOS build & release: <https://docs.flutter.dev/deployment/macos>
