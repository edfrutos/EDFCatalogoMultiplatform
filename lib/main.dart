import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle; // Para rootBundle solo en web
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'utils/env_config.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'views/content_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde múltiples ubicaciones posibles
  bool envLoaded = false;

  // Para web, cargar como asset usando rootBundle
  if (kIsWeb) {
    try {
      // En web, cargar manualmente desde rootBundle y parsear
      final String envString = await rootBundle.loadString('.env');
      // Parsear manualmente el string
      final lines = envString.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final value = parts.sublist(1).join('=').trim();
            // Limpiar comillas si existen
            final cleanValue = value
                .replaceAll(RegExp(r'^"'), '')
                .replaceAll(RegExp(r'"$'), '')
                .replaceAll(RegExp(r"^'"), '')
                .replaceAll(RegExp(r"'$"), '');
            dotenv.env[key] = cleanValue;
          }
        }
      }
      print('✅ Variables de entorno cargadas manualmente desde asset para web');
      print('📋 Variables cargadas: ${dotenv.env.keys.length}');
      envLoaded = true;
    } catch (e) {
      print('⚠️ Error al cargar .env en web: $e');
      print(
        '⚠️ La aplicación continuará pero puede no funcionar correctamente',
      );
    }
  } else {
    // Para macOS/iOS/Android/Desktop, buscar archivo físico
    // No intentar cargar desde assets en desktop - solo buscar en sistema de archivos
    // Los assets solo funcionan bien en web

    // Para macOS, buscar PRIMERO en el bundle del sistema de archivos
    // Esto es crítico porque el sandbox puede bloquear acceso a archivos fuera del bundle
    if (!envLoaded && Platform.isMacOS) {
      try {
        final bundlePath = Platform.resolvedExecutable;
        final bundleDir = File(
          bundlePath,
        ).parent.parent; // Contents/MacOS -> Contents
        final envPath = '${bundleDir.path}/Resources/.env';
        print('🔍 Buscando .env en bundle (PRIORIDAD): $envPath');
        if (File(envPath).existsSync()) {
          // Intentar cargar primero con dotenv (método más confiable)
          try {
            await dotenv.load(fileName: envPath);
            print('✅ Variables cargadas con dotenv desde bundle: $envPath');
            envLoaded = true;
          } catch (e) {
            // Si dotenv falla, intentar lectura manual como fallback
            print('⚠️ dotenv falló, intentando lectura manual: $e');
            try {
              final file = File(envPath);
              final content = await file.readAsString();
              final lines = content.split('\n');

              // Parsear manualmente
              for (final line in lines) {
                final trimmed = line.trim();
                if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
                  final parts = trimmed.split('=');
                  if (parts.length >= 2) {
                    final key = parts[0].trim();
                    final value = parts.sublist(1).join('=').trim();
                    // Limpiar comillas si existen
                    final cleanValue = value
                        .replaceAll(RegExp(r'^"'), '')
                        .replaceAll(RegExp(r'"$'), '')
                        .replaceAll(RegExp(r"^'"), '')
                        .replaceAll(RegExp(r"'$"), '');
                    dotenv.env[key] = cleanValue;
                  }
                }
              }
              print('✅ Variables de entorno cargadas manualmente desde bundle');
              envLoaded = true;
            } catch (e2) {
              print('⚠️ Error también con lectura manual desde bundle: $e2');
            }
          }
        } else {
          print('⚠️ .env no encontrado en bundle: $envPath');
        }
      } catch (e) {
        print('⚠️ Error buscando en bundle: $e');
        // Continuar con otras ubicaciones
      }
    }

    // Buscar en ubicaciones relativas al proyecto (solo si no está cargado)
    // NOTA: En macOS con sandbox, estas rutas pueden no ser accesibles
    if (!envLoaded) {
      // Obtener el directorio del script ejecutable y buscar hacia arriba
      String? projectRoot;
      if (!kIsWeb && Platform.resolvedExecutable.isNotEmpty) {
        try {
          var current = File(Platform.resolvedExecutable).parent; // MacOS
          current = current.parent; // Contents
          current = current.parent; // .app
          current = current.parent; // Products/Debug
          current = current.parent; // Products
          current = current.parent; // Build
          // Aquí podría ser macos o directamente la raíz del proyecto
          // Si el siguiente nivel es macos, subir uno más para llegar a la raíz
          if (current.path.endsWith('build')) {
            var parent = current.parent;
            // Verificar si el nombre del directorio parece ser el proyecto
            if (parent.path.contains('EDFCatalogoMultiplatform')) {
              projectRoot = parent.path;
            } else {
              // Si no, podría ser que estemos en build/macos, subir dos niveles
              current = current.parent; // Debería ser la raíz
              projectRoot = current.path;
            }
          } else {
            projectRoot = current.path;
          }
          print('🔍 Ruta calculada del proyecto: $projectRoot');
        } catch (e) {
          print('⚠️ Error calculando ruta del proyecto: $e');
        }
      }

      final possiblePaths = <String>[];

      // AGREGAR: Buscar directamente en la raíz del proyecto (desarrollo)
      // Buscar subiendo desde el directorio actual hasta encontrar pubspec.yaml
      try {
        var searchDir = Directory(Directory.current.path);
        for (int i = 0; i < 15; i++) {
          final pubspecPath = File('${searchDir.path}/pubspec.yaml');
          final envPath = File('${searchDir.path}/.env');
          if (pubspecPath.existsSync()) {
            // Encontramos la raíz del proyecto
            if (envPath.existsSync()) {
              possiblePaths.insert(
                0,
                envPath.path,
              ); // Insertar al inicio para prioridad
              print('✅ Encontrado .env en raíz del proyecto: ${envPath.path}');
            }
            break;
          }
          if (searchDir.path == searchDir.parent.path)
            break; // Llegamos a la raíz del sistema
          searchDir = searchDir.parent;
        }

        // También buscar desde la ruta absoluta del proyecto conocida
        final projectRootPath =
            '/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform';
        final knownEnvPath = File('$projectRootPath/.env');
        if (knownEnvPath.existsSync() &&
            !possiblePaths.contains(knownEnvPath.path)) {
          possiblePaths.insert(0, knownEnvPath.path);
          print('✅ Encontrado .env en ruta conocida: ${knownEnvPath.path}');
        }
      } catch (e) {
        print('⚠️ Error buscando .env en raíz: $e');
      }

      // Si encontramos la raíz del proyecto, buscar ahí primero
      if (projectRoot != null) {
        possiblePaths.add('$projectRoot/.env');
        print('🔍 Añadida ruta del proyecto: $projectRoot/.env');
      }

      // También buscar en el directorio de trabajo actual (útil con flutter run)
      final currentWorkingDir = Directory.current.path;
      // Si el directorio actual contiene pubspec.yaml, es la raíz del proyecto
      final pubspecPath = File('$currentWorkingDir/pubspec.yaml');
      if (pubspecPath.existsSync()) {
        possiblePaths.add('$currentWorkingDir/.env');
        print(
          '🔍 Añadida ruta del directorio actual (raíz del proyecto): $currentWorkingDir/.env',
        );
      } else {
        possiblePaths.add('$currentWorkingDir/.env');
      }

      // Agregar rutas comunes
      possiblePaths.addAll([
        '.env', // Relativo al directorio actual
      ]);

      // Solo intentar Platform.resolvedExecutable si no es web
      if (!kIsWeb && Platform.resolvedExecutable.isNotEmpty) {
        try {
          final scriptFile = File(Platform.resolvedExecutable);
          final scriptDir =
              scriptFile.parent.parent.parent; // Contents/MacOS/App.app
          // Buscar en Resources del bundle
          possiblePaths.add('${scriptDir.path}/Resources/.env');
          // También buscar subiendo niveles desde el bundle
          var current = scriptDir;
          for (int i = 0; i < 6; i++) {
            possiblePaths.add('${current.path}/.env');
            current = current.parent;
          }
        } catch (e) {
          // Ignorar error
        }
      }

      // Rutas relativas
      possiblePaths.addAll(['../.env', '../../.env', '../../../.env']);

      print('🔍 Buscando archivo .env en:');
      for (final path in possiblePaths.toSet()) {
        // Usar Set para evitar duplicados
        print('   - $path');
        try {
          final file = File(path);
          final exists = file.existsSync();
          print('      ${exists ? "✅ EXISTE" : "❌ NO existe"}');
          if (exists) {
            try {
              // Leer el archivo manualmente para rutas absolutas
              final file = File(path);
              final content = await file.readAsString();
              final lines = content.split('\n');

              // Parsear manualmente
              for (final line in lines) {
                final trimmed = line.trim();
                if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
                  final parts = trimmed.split('=');
                  if (parts.length >= 2) {
                    final key = parts[0].trim();
                    final value = parts.sublist(1).join('=').trim();
                    // Limpiar comillas si existen
                    final cleanValue = value
                        .replaceAll(RegExp(r'^"'), '')
                        .replaceAll(RegExp(r'"$'), '')
                        .replaceAll(RegExp(r"^'"), '')
                        .replaceAll(RegExp(r"'$"), '');
                    dotenv.env[key] = cleanValue;
                  }
                }
              }

              print('✅ Variables de entorno cargadas desde: $path');
              print('📋 Verificando variables cargadas...');
              print(
                '   MONGO_URI: ${dotenv.env['MONGO_URI']?.isNotEmpty == true ? "✅ Cargada" : "❌ Vacía"}',
              );
              print(
                '   MONGO_DB: ${dotenv.env['MONGO_DB']?.isNotEmpty == true ? "✅ Cargada" : "❌ Vacía"}',
              );
              envLoaded = true;
              break;
            } catch (loadError) {
              print('      ⚠️ Error al leer el archivo: $loadError');
              // Intentar con dotenv.load como fallback
              try {
                await dotenv.load(fileName: path);
                print('✅ Variables cargadas con dotenv.load()');
                envLoaded = true;
                break;
              } catch (e) {
                print('      ⚠️ Error también con dotenv.load(): $e');
                continue;
              }
            }
          }
        } catch (e) {
          print('      ⚠️ Error al verificar/cargar: $e');
          continue;
        }
      }
    }
  }

  if (!envLoaded) {
    print(
      '⚠️ No se encontró el archivo .env. La aplicación puede no funcionar correctamente sin configuración.',
    );
    print(
      '💡 Asegúrate de que el archivo .env existe en la raíz del proyecto.',
    );
  }

  // Validar configuración
  if (envLoaded && !EnvConfig.validate()) {
    print(
      '⚠️ Advertencia: Algunas variables de entorno críticas no están configuradas',
    );
  }

  // Configurar manejo de errores para debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ Error de Flutter: ${details.exception}');
    if (details.stack != null) {
      print('📋 Stack trace: ${details.stack}');
    }
  };

  // Ejecutar la app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
          create: (_) => AdminViewModel(),
          update: (_, authViewModel, previous) => previous ?? AdminViewModel(),
        ),
      ],
      child: MaterialApp(
        title: 'EDF Catálogo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ContentView(),
      ),
    );
  }
}
