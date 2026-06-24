import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'utils/env_config.dart';
import 'utils/env_loader.dart';
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
