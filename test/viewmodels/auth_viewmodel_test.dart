// Tests unitarios de AuthViewModel
//
// Usa mocktail para aislar AuthViewModel de MongoService y KeychainService.
// No requiere conexión a MongoDB ni a llavero del sistema.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:edfcatalogomultiplatform/models/user.dart';
import 'package:edfcatalogomultiplatform/services/keychain_service.dart';
import 'package:edfcatalogomultiplatform/services/mongo_service.dart';
import 'package:edfcatalogomultiplatform/viewmodels/auth_viewmodel.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockMongoService extends Mock implements MongoService {}

class MockKeychainService extends Mock implements KeychainService {}

// ── Fixture ───────────────────────────────────────────────────────────────────

final _testUser = User(
  id: 'user-123',
  email: 'test@example.com',
  username: 'testuser',
  name: 'Test User',
  isAdmin: false,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockMongoService mongo;
  late MockKeychainService keychain;
  late AuthViewModel vm;

  setUp(() {
    mongo = MockMongoService();
    keychain = MockKeychainService();
    vm = AuthViewModel(mongoService: mongo, keychainService: keychain);
  });

  // ── Estado inicial ──────────────────────────────────────────────────────────

  group('estado inicial', () {
    test('no está autenticado', () {
      expect(vm.isAuthenticated, isFalse);
    });

    test('no está cargando', () {
      expect(vm.isLoading, isFalse);
    });

    test('currentUser es null', () {
      expect(vm.currentUser, isNull);
    });

    test('errorMessage es null', () {
      expect(vm.errorMessage, isNull);
    });
  });

  // ── signIn ──────────────────────────────────────────────────────────────────

  group('signIn', () {
    test('establece isLoading=true durante la llamada y false al terminar',
        () async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _testUser);

      when(() => keychain.saveToken(any())).thenAnswer((_) async {});
      when(() => keychain.saveEmail(any())).thenAnswer((_) async {});
      when(() => keychain.saveUserId(any())).thenAnswer((_) async {});

      final future = vm.signIn(emailOrUsername: 'test@example.com', password: 'pass');
      // Durante la espera, isLoading debería ser true
      expect(vm.isLoading, isTrue);
      await future;
      expect(vm.isLoading, isFalse);
    });

    test('autentica correctamente con credenciales válidas', () async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: 'test@example.com',
          password: 'correctpass',
        ),
      ).thenAnswer((_) async => _testUser);

      when(() => keychain.saveToken(any())).thenAnswer((_) async {});
      when(() => keychain.saveEmail(any())).thenAnswer((_) async {});
      when(() => keychain.saveUserId(any())).thenAnswer((_) async {});

      await vm.signIn(
          emailOrUsername: 'test@example.com', password: 'correctpass');

      expect(vm.isAuthenticated, isTrue);
      expect(vm.currentUser, _testUser);
      expect(vm.errorMessage, isNull);
    });

    test('establece errorMessage cuando las credenciales son vacías', () async {
      await vm.signIn(emailOrUsername: '', password: '');

      expect(vm.isAuthenticated, isFalse);
      expect(vm.errorMessage, isNotNull);
      // No debe llamar a Mongo si la validación local falla
      verifyNever(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      );
    });

    test('establece errorMessage cuando Mongo devuelve null (credenciales incorrectas)',
        () async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => null);

      await vm.signIn(
          emailOrUsername: 'wrong@example.com', password: 'wrongpass');

      expect(vm.isAuthenticated, isFalse);
      expect(vm.errorMessage, isNotNull);
    });

    test('no guarda sesión en keychain cuando rememberMe=false', () async {
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _testUser);

      when(() => keychain.clearAuthData()).thenAnswer((_) async {});

      await vm.signIn(
        emailOrUsername: 'test@example.com',
        password: 'pass',
        rememberMe: false,
      );

      verifyNever(() => keychain.saveToken(any()));
      verify(() => keychain.clearAuthData()).called(1);
    });
  });

  // ── signOut ─────────────────────────────────────────────────────────────────

  group('signOut', () {
    setUp(() async {
      // Autenticar primero
      when(
        () => mongo.authenticateUser(
          emailOrUsername: any(named: 'emailOrUsername'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _testUser);
      when(() => keychain.saveToken(any())).thenAnswer((_) async {});
      when(() => keychain.saveEmail(any())).thenAnswer((_) async {});
      when(() => keychain.saveUserId(any())).thenAnswer((_) async {});

      await vm.signIn(emailOrUsername: 'test@example.com', password: 'pass');
    });

    test('limpia el estado de autenticación', () {
      when(() => keychain.clearAuthData()).thenAnswer((_) async {});

      vm.signOut();

      expect(vm.isAuthenticated, isFalse);
      expect(vm.currentUser, isNull);
      expect(vm.errorMessage, isNull);
    });

    test('llama a keychain.clearAuthData()', () {
      when(() => keychain.clearAuthData()).thenAnswer((_) async {});

      vm.signOut();

      verify(() => keychain.clearAuthData()).called(1);
    });
  });
}
