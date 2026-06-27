import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'utils/app_theme.dart';
import 'utils/env_config.dart';
import 'utils/env_loader.dart';
import 'utils/theme_provider.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/content_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  // Cargar variables de entorno (lógica centralizada en env_loader.dart)
  final envLoaded = await initEnv();
  if (!envLoaded) {
    print('⚠️ .env no encontrado. La app puede no funcionar correctamente.');
  } else if (!EnvConfig.validate()) {
    print('⚠️ Faltan variables de entorno críticas (MONGO_URI / MONGO_DB).');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ Flutter error: ${details.exception}');
  };

  // Cargar preferencia de tema antes de arrancar
  final themeProvider = ThemeProvider();
  await themeProvider.loadFromPrefs();

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
          create: (_) => AdminViewModel(),
          update: (_, authViewModel, previous) => previous ?? AdminViewModel(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp(
            title: 'EDF Catálogo',
            debugShowCheckedModeBanner: false,
            themeMode: themeProv.mode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            // Evita aserción trackpad en macOS:
            // PointerDownEvent no admite PointerDeviceKind.trackpad
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            home: const ContentView(),
          );
        },
      ),
    );
  }
}
