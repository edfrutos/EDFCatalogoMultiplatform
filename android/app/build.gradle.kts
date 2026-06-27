import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Signing config ────────────────────────────────────────────────────────────
// Local: lee android/key.properties (gitignored)
// CI:    usa variables de entorno inyectadas por GitHub Actions Secrets
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

fun signingProp(key: String): String =
    keyProperties.getProperty(key) ?: System.getenv(key) ?: ""

android {
    namespace = "com.edfcatalogo.edfcatalogomultiplatform"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.edfcatalogo.edfcatalogomultiplatform"
        minSdk = 23 // EncryptedSharedPreferences (flutter_secure_storage) requiere API 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile     = file(signingProp("storeFile").ifEmpty { "missing.jks" })
            storePassword = signingProp("storePassword")
            keyAlias      = signingProp("keyAlias")
            keyPassword   = signingProp("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingProp("storePassword").isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback a debug si no hay credenciales (builds de CI sin secrets)
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
