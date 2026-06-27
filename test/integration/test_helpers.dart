// test/integration/test_helpers.dart
//
// Helpers y fixtures comunes para los tests de integración de widget.
// No requieren dispositivo ni conexión a MongoDB.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:edfcatalogomultiplatform/models/user.dart';
import 'package:edfcatalogomultiplatform/services/keychain_service.dart';
import 'package:edfcatalogomultiplatform/services/mongo_service.dart';
import 'package:edfcatalogomultiplatform/utils/app_theme.dart';
import 'package:edfcatalogomultiplatform/utils/theme_provider.dart';
import 'package:edfcatalogomultiplatform/viewmodels/admin_viewmodel.dart';
import 'package:edfcatalogomultiplatform/viewmodels/auth_viewmodel.dart';
import 'package:edfcatalogomultiplatform/views/content_view.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockMongoService extends Mock implements MongoService {}

class MockKeychainService extends Mock implements KeychainService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const testUser = User(
  id: 'u-test-001',
  email: 'test@edf.test',
  username: 'testuser',
  name: 'Test User',
  isAdmin: false,
);

const adminUser = User(
  id: 'u-admin-001',
  email: 'admin@edf.test',
  username: 'admin',
  name: 'Admin Test',
  isAdmin: true,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Desactiva la descarga de fuentes en tests (evita errores de red).
void disableGoogleFontsFetch() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Construye el árbol completo de la app con el [authVm] inyectado.
Widget buildApp(AuthViewModel authVm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
      ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
        create: (_) => AdminViewModel(),
        update: (_, _, prev) => prev ?? AdminViewModel(),
      ),
    ],
    child: Consumer<ThemeProvider>(
      builder: (_, themeProv, _) => MaterialApp(
        title: 'EDF Test',
        debugShowCheckedModeBanner: false,
        themeMode: themeProv.mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const ContentView(),
      ),
    ),
  );
}

/// Construye un widget aislado con providers mínimos.
Widget buildIsolated({
  required AuthViewModel authVm,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
      ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
        create: (_) => AdminViewModel(),
        update: (_, _, prev) => prev ?? AdminViewModel(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

/// Configura stubs de keychain para un login exitoso.
void stubKeychainForLogin(MockKeychainService keychain) {
  when(() => keychain.saveToken(any())).thenAnswer((_) async => true);
  when(() => keychain.saveEmail(any())).thenAnswer((_) async => true);
  when(() => keychain.saveUserId(any())).thenAnswer((_) async => true);
  when(() => keychain.clearAuthData()).thenAnswer((_) async {});
}
