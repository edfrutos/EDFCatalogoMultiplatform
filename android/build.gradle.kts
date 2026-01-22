allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuración global para todos los subproyectos Android
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            
            // Aplicar configuración de SDK común si no está definida
            try {
                val compileSdkField = android.javaClass.getMethod("getCompileSdk")
                if (compileSdkField.invoke(android) == null || compileSdkField.invoke(android) == 0) {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                    setCompileSdk.invoke(android, 34)
                }
            } catch (e: Exception) {
                // Si hay error, configurar directamente
                try {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                    setCompileSdk.invoke(android, 34)
                } catch (ex: Exception) {
                    // Ignorar si no se puede configurar
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
