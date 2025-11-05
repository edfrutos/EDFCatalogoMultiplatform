import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mongo_service.dart';
import '../utils/env_config.dart';
import '../models/backup_info.dart';

/// Servicio para gestionar backups en Google Drive
/// NOTA: Requiere configuración de OAuth 2.0 en Google Cloud Console
/// Para aplicaciones desktop, se necesita un servidor local para recibir el código OAuth
class GoogleDriveBackupService {
  static final GoogleDriveBackupService _instance =
      GoogleDriveBackupService._internal();
  factory GoogleDriveBackupService() => _instance;
  GoogleDriveBackupService._internal();

  drive.DriveApi? _driveApi;
  auth.AutoRefreshingAuthClient? _authClient;
  bool _isInitialized = false;
  String? _backupFolderId;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _refreshTokenKey = 'google_drive_refresh_token';
  static const String _accessTokenKey = 'google_drive_access_token';
  static const String _tokenExpiryKey = 'google_drive_token_expiry';

  // Usar SharedPreferences como fallback cuando secure storage falla
  static SharedPreferences? _prefs;

  /// Inicializar el servicio de Google Drive con OAuth 2.0
  /// NOTA: La primera vez abrirá el navegador para autenticación
  /// Si hay un token guardado, lo reutilizará
  Future<void> initialize({Function(String)? onAuthUrl}) async {
    if (_isInitialized) return;

    try {
      final clientId = EnvConfig.googleClientId;
      final clientSecret = EnvConfig.googleClientSecret;
      final folderName = EnvConfig.googleDriveFolder;

      if (clientId.isEmpty || clientSecret.isEmpty) {
        throw Exception(
          'GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET deben estar configurados en .env',
        );
      }

      // Configurar OAuth 2.0 para aplicación desktop
      final identifier = auth.ClientId(clientId, clientSecret);
      final scopes = [drive.DriveApi.driveFileScope];

      // Intentar cargar token guardado primero
      auth.AutoRefreshingAuthClient? authClient = await _loadSavedCredentials(
        identifier,
        scopes,
      );

      // Si no hay token guardado o está expirado, autenticar de nuevo
      if (authClient == null) {
        print('🔑 No hay token guardado, iniciando autenticación OAuth...');
        authClient = await _authenticateWithLocalServer(
          identifier,
          scopes,
          onAuthUrl: onAuthUrl,
        );

        if (authClient == null) {
          throw Exception(
            'No se pudo autenticar con Google Drive. Verifica las credenciales OAuth.',
          );
        }
      } else {
        print('✅ Token de Google Drive restaurado desde almacenamiento seguro');
      }

      _authClient = authClient;

      // Crear cliente de Drive API con el cliente autenticado
      _driveApi = drive.DriveApi(_authClient!);

      // Buscar o crear la carpeta de backups
      _backupFolderId = await _findOrCreateBackupFolder(folderName);

      _isInitialized = true;
      print('✅ Google Drive Backup Service inicializado correctamente');
      print('📁 Carpeta de backups: $folderName (ID: $_backupFolderId)');
    } catch (e) {
      print('❌ Error inicializando Google Drive Backup Service: $e');
      print('💡 Asegúrate de:');
      print(
        '   1. Tener GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET configurados en .env',
      );
      print(
        '   2. Haber configurado http://localhost:8080/oauth2callback como redirect URI en Google Cloud Console',
      );
      print(
        '   3. Haber habilitado la API de Google Drive en Google Cloud Console',
      );
      rethrow;
    }
  }

  /// Cargar credenciales guardadas desde secure storage (con fallback a SharedPreferences)
  Future<auth.AutoRefreshingAuthClient?> _loadSavedCredentials(
    auth.ClientId clientId,
    List<String> scopes,
  ) async {
    try {
      String? refreshToken;
      String? accessToken;
      String? expiryStr;

      // Intentar cargar desde secure storage primero
      try {
        refreshToken = await _secureStorage.read(key: _refreshTokenKey);
        accessToken = await _secureStorage.read(key: _accessTokenKey);
        expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
      } catch (e) {
        // Si secure storage falla (p.ej. en macOS sin certificado), usar SharedPreferences
        print(
          '⚠️ Secure storage no disponible, usando SharedPreferences como fallback',
        );
      }

      // Si no se encontró token en secure storage, intentar SharedPreferences
      if (refreshToken == null) {
        try {
          _prefs ??= await SharedPreferences.getInstance();
          refreshToken = _prefs!.getString(_refreshTokenKey);
          accessToken = _prefs!.getString(_accessTokenKey);
          expiryStr = _prefs!.getString(_tokenExpiryKey);
          if (refreshToken != null) {
            print('✅ Token encontrado en SharedPreferences (fallback)');
          }
        } catch (e) {
          print('⚠️ Error cargando desde SharedPreferences: $e');
        }
      }

      if (refreshToken == null) {
        return null; // No hay token guardado
      }

      // Si hay refresh token, intentar crear credenciales
      DateTime? expiry;
      if (expiryStr != null) {
        try {
          expiry = DateTime.parse(expiryStr);
        } catch (e) {
          print('⚠️ Error parseando fecha de expiración: $e');
        }
      }

      // Si el access token está expirado o no existe, usar solo refresh token
      auth.AccessCredentials credentials;
      if (accessToken != null &&
          expiry != null &&
          expiry.isAfter(DateTime.now())) {
        // Usar access token existente si aún no ha expirado
        credentials = auth.AccessCredentials(
          auth.AccessToken('Bearer', accessToken, expiry),
          refreshToken,
          scopes,
        );
      } else {
        // Crear credenciales con solo refresh token (el cliente las refrescará)
        credentials = auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            'dummy',
            DateTime.now().subtract(Duration(days: 1)),
          ),
          refreshToken,
          scopes,
        );
      }

      final httpClient = http.Client();
      final authClient = auth.autoRefreshingClient(
        clientId,
        credentials,
        httpClient,
      );

      return authClient;
    } catch (e) {
      print('⚠️ Error cargando credenciales guardadas: $e');
      return null;
    }
  }

  /// Guardar credenciales en secure storage (con fallback a SharedPreferences)
  Future<void> _saveCredentials(auth.AccessCredentials credentials) async {
    try {
      if (credentials.refreshToken != null) {
        // Intentar guardar en secure storage primero
        try {
          await _secureStorage.write(
            key: _refreshTokenKey,
            value: credentials.refreshToken!,
          );
          // Guardar también access token y expiry
          await _secureStorage.write(
            key: _accessTokenKey,
            value: credentials.accessToken.data,
          );
          await _secureStorage.write(
            key: _tokenExpiryKey,
            value: credentials.accessToken.expiry.toIso8601String(),
          );
          print('💾 Credenciales de Google Drive guardadas en secure storage');
        } catch (e) {
          // Si secure storage falla (p.ej. en macOS sin certificado), usar SharedPreferences
          print(
            '⚠️ Secure storage no disponible, usando SharedPreferences como fallback: $e',
          );
          _prefs ??= await SharedPreferences.getInstance();
          await _prefs!.setString(_refreshTokenKey, credentials.refreshToken!);
          await _prefs!.setString(
            _accessTokenKey,
            credentials.accessToken.data,
          );
          await _prefs!.setString(
            _tokenExpiryKey,
            credentials.accessToken.expiry.toIso8601String(),
          );
          print(
            '💾 Credenciales de Google Drive guardadas en SharedPreferences (fallback)',
          );
        }
      }
    } catch (e) {
      print('⚠️ Error guardando credenciales: $e');
    }
  }

  /// Autenticar usando un servidor HTTP local para recibir el código OAuth
  Future<auth.AutoRefreshingAuthClient?> _authenticateWithLocalServer(
    auth.ClientId clientId,
    List<String> scopes, {
    Function(String)? onAuthUrl,
  }) async {
    HttpServer? server;

    try {
      // Crear servidor HTTP local en puerto 8080
      server = await HttpServer.bind('localhost', 8080);
      print('🌐 Servidor OAuth iniciado en http://localhost:8080');

      // Generar URL de autorización para Google
      final authUri = 'https://accounts.google.com/o/oauth2/v2/auth';
      final tokenUri = 'https://oauth2.googleapis.com/token';

      final params = {
        'client_id': clientId.identifier,
        'redirect_uri': 'http://localhost:8080/oauth2callback',
        'response_type': 'code',
        'scope': scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
      };

      final uri = Uri.parse(authUri).replace(
        queryParameters: params.map((key, value) => MapEntry(key, value)),
      );

      // Mostrar URL al usuario y abrir en navegador
      if (onAuthUrl != null) {
        onAuthUrl(uri.toString());
      }

      print('🔗 Abriendo navegador para autenticación...');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Esperar a recibir el código de autorización
      String? authCode;
      await for (final request in server) {
        final uri = request.requestedUri;

        if (uri.path == '/oauth2callback') {
          authCode = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];

          if (error != null) {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.html
              ..write(
                '<html><body><h1>Error de autorización</h1><p>$error</p></body></html>',
              );
            await request.response.close();
            throw Exception('Error de autorización: $error');
          }

          if (authCode != null) {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write(
                '<html><body><h1>Autorización exitosa</h1><p>Puedes cerrar esta ventana.</p></body></html>',
              );
            await request.response.close();
            break;
          }
        } else {
          request.response
            ..statusCode = 404
            ..write('Not found');
          await request.response.close();
        }
      }

      if (authCode == null) {
        throw Exception('No se recibió el código de autorización');
      }

      // Intercambiar código por token de acceso
      final tokenUriParsed = Uri.parse(tokenUri);

      // Codificar el body como application/x-www-form-urlencoded
      final bodyParams = <String, String>{
        'code': authCode,
        'client_id': clientId.identifier,
        'client_secret': clientId.secret ?? '',
        'redirect_uri': 'http://localhost:8080/oauth2callback',
        'grant_type': 'authorization_code',
      };

      final bodyString = bodyParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final tokenResponse = await http.post(
        tokenUriParsed,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyString,
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Error obteniendo token: ${tokenResponse.body}');
      }

      final tokenData = json.decode(tokenResponse.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int? ?? 3600;

      // Crear credenciales
      final credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
        ),
        refreshToken,
        scopes,
      );

      // Crear cliente autenticado con auto-refresh
      final httpClient = http.Client();
      final authClient = auth.autoRefreshingClient(
        clientId,
        credentials,
        httpClient,
      );

      // Guardar credenciales para uso futuro
      await _saveCredentials(credentials);

      return authClient;
    } catch (e) {
      print('❌ Error en autenticación OAuth: $e');
      return null;
    } finally {
      // Cerrar servidor
      await server?.close();
      print('🔒 Servidor OAuth cerrado');
    }
  }

  /// Buscar o crear la carpeta de backups en Google Drive
  Future<String?> _findOrCreateBackupFolder(String folderName) async {
    if (_driveApi == null) return null;

    try {
      // Buscar carpeta existente
      final query =
          "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final response = await _driveApi!.files.list(q: query, spaces: 'drive');

      if (response.files != null && response.files!.isNotEmpty) {
        return response.files!.first.id;
      }

      // Crear carpeta si no existe
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await _driveApi!.files.create(folder);
      return created.id;
    } catch (e) {
      print('⚠️ Error buscando/creando carpeta: $e');
      return null;
    }
  }

  /// Verificar si el servicio está inicializado
  bool get isInitialized => _isInitialized && _driveApi != null;

  /// Crear backup de todos los catálogos
  Future<String> backupCatalogs() async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      throw Exception('Servicio no inicializado correctamente');
    }

    try {
      final mongoService = MongoService();
      final catalogs = await mongoService.getCatalogs(
        '', // userId vacío
        isAdmin: true, // true para poder obtener todos
      );

      // Convertir catálogos a JSON
      final catalogsJson = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'count': catalogs.length,
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
      };

      final jsonString = json.encode(catalogsJson);
      final jsonBytes = utf8.encode(jsonString);

      // Generar nombre del archivo
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'catalogs_backup_$timestamp.json';

      // Crear archivo en Drive
      final file = drive.File()
        ..name = fileName
        ..parents = [_backupFolderId!]
        ..mimeType = 'application/json';

      final media = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      );

      final created = await _driveApi!.files.create(file, uploadMedia: media);

      print(
        '✅ Backup de catálogos creado en Google Drive: $fileName (ID: ${created.id})',
      );
      return created.id ?? fileName;
    } catch (e) {
      print('❌ Error creando backup de catálogos: $e');
      rethrow;
    }
  }

  /// Crear backup de todos los usuarios
  Future<String> backupUsers() async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      throw Exception('Servicio no inicializado correctamente');
    }

    try {
      final mongoService = MongoService();
      final users = await mongoService.getAllUsers();

      // Convertir usuarios a JSON (sin contraseñas)
      final usersJson = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'count': users.length,
        'users': users.map((u) {
          final userJson = u.toJson();
          // No incluir contraseñas en el backup
          userJson.remove('password');
          userJson.remove('passwordHash');
          return userJson;
        }).toList(),
      };

      final jsonString = json.encode(usersJson);
      final jsonBytes = utf8.encode(jsonString);

      // Generar nombre del archivo
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'users_backup_$timestamp.json';

      // Crear archivo en Drive
      final file = drive.File()
        ..name = fileName
        ..parents = [_backupFolderId!]
        ..mimeType = 'application/json';

      final media = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      );

      final created = await _driveApi!.files.create(file, uploadMedia: media);

      print(
        '✅ Backup de usuarios creado en Google Drive: $fileName (ID: ${created.id})',
      );
      return created.id ?? fileName;
    } catch (e) {
      print('❌ Error creando backup de usuarios: $e');
      rethrow;
    }
  }

  /// Listar todos los backups de catálogos
  Future<List<BackupInfo>> listCatalogBackups() async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      return [];
    }

    try {
      final query =
          "'$_backupFolderId' in parents and name contains 'catalogs_backup' and mimeType='application/json' and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        spaces: 'drive',
      );

      final backups = <BackupInfo>[];
      if (response.files != null) {
        for (final file in response.files!) {
          // Obtener tamaño del archivo
          int fileSize = 0;
          if (file.size != null && file.size!.isNotEmpty) {
            fileSize = int.tryParse(file.size!) ?? 0;
          } else {
            // Si el tamaño no está en el listado, obtenerlo del archivo completo
            try {
              if (file.id != null) {
                final fileDetails =
                    await _driveApi!.files.get(file.id!) as drive.File;
                if (fileDetails.size != null && fileDetails.size!.isNotEmpty) {
                  fileSize = int.tryParse(fileDetails.size!) ?? 0;
                }
              }
            } catch (e) {
              print(
                '⚠️ No se pudo obtener el tamaño del archivo ${file.name}: $e',
              );
            }
          }

          backups.add(
            BackupInfo(
              name: file.name ?? 'unknown',
              size: fileSize,
              created: file.createdTime ?? DateTime.now(),
              type: BackupType.catalogs,
              driveFileId: file.id,
            ),
          );
        }
      }

      return backups;
    } catch (e) {
      print('❌ Error listando backups de catálogos: $e');
      rethrow;
    }
  }

  /// Listar todos los backups de usuarios
  Future<List<BackupInfo>> listUserBackups() async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      return [];
    }

    try {
      final query =
          "'$_backupFolderId' in parents and name contains 'users_backup' and mimeType='application/json' and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        spaces: 'drive',
      );

      final backups = <BackupInfo>[];
      if (response.files != null) {
        for (final file in response.files!) {
          // Obtener tamaño del archivo
          int fileSize = 0;
          if (file.size != null && file.size!.isNotEmpty) {
            fileSize = int.tryParse(file.size!) ?? 0;
          } else {
            // Si el tamaño no está en el listado, obtenerlo del archivo completo
            try {
              if (file.id != null) {
                final fileDetails =
                    await _driveApi!.files.get(file.id!) as drive.File;
                if (fileDetails.size != null && fileDetails.size!.isNotEmpty) {
                  fileSize = int.tryParse(fileDetails.size!) ?? 0;
                }
              }
            } catch (e) {
              print(
                '⚠️ No se pudo obtener el tamaño del archivo ${file.name}: $e',
              );
            }
          }

          backups.add(
            BackupInfo(
              name: file.name ?? 'unknown',
              size: fileSize,
              created: file.createdTime ?? DateTime.now(),
              type: BackupType.users,
              driveFileId: file.id,
            ),
          );
        }
      }

      return backups;
    } catch (e) {
      print('❌ Error listando backups de usuarios: $e');
      rethrow;
    }
  }

  /// Descargar un backup
  Future<Map<String, dynamic>> downloadBackup(String fileId) async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null) {
      throw Exception('Servicio no inicializado');
    }

    try {
      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Leer el contenido
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final jsonString = utf8.decode(bytes);
      final data = json.decode(jsonString) as Map<String, dynamic>;

      return data;
    } catch (e) {
      print('❌ Error descargando backup: $e');
      rethrow;
    }
  }

  /// Eliminar un backup
  Future<void> deleteBackup(String fileId) async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null) {
      throw Exception('Servicio no inicializado');
    }

    try {
      await _driveApi!.files.delete(fileId);
      print('✅ Backup eliminado de Google Drive: $fileId');
    } catch (e) {
      print('❌ Error eliminando backup: $e');
      rethrow;
    }
  }

  /// Subir backup del proyecto a Google Drive
  /// [zipFilePath] - Ruta del archivo ZIP del backup
  /// Retorna el ID del archivo en Google Drive
  Future<String> uploadProjectBackup(String zipFilePath) async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      throw Exception('Servicio no inicializado correctamente');
    }

    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('El archivo ZIP no existe: $zipFilePath');
      }

      // Leer el archivo ZIP
      final zipBytes = await zipFile.readAsBytes();
      final fileName = path.basename(zipFilePath);

      return await _uploadZipBytes(zipBytes, fileName);
    } catch (e) {
      print('❌ Error subiendo backup del proyecto: $e');
      rethrow;
    }
  }

  /// Subir backup del proyecto a Google Drive desde bytes en memoria
  /// [zipBytes] - Bytes del archivo ZIP
  /// [fileName] - Nombre del archivo
  /// Retorna el ID del archivo en Google Drive
  Future<String> uploadProjectBackupFromBytes(
    List<int> zipBytes,
    String fileName,
  ) async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      throw Exception('Servicio no inicializado correctamente');
    }

    try {
      return await _uploadZipBytes(zipBytes, fileName);
    } catch (e) {
      print('❌ Error subiendo backup del proyecto: $e');
      rethrow;
    }
  }

  /// Método privado para subir bytes ZIP a Google Drive
  Future<String> _uploadZipBytes(List<int> zipBytes, String fileName) async {
    print('📤 Subiendo backup del proyecto a Google Drive: $fileName');
    print(
      '   Tamaño: ${(zipBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Crear archivo en Drive
    final file = drive.File()
      ..name = fileName
      ..parents = [_backupFolderId!]
      ..mimeType = 'application/zip';

    final media = drive.Media(
      Stream.value(zipBytes),
      zipBytes.length,
      contentType: 'application/zip',
    );

    final created = await _driveApi!.files.create(file, uploadMedia: media);

    print(
      '✅ Backup del proyecto subido a Google Drive: $fileName (ID: ${created.id})',
    );
    return created.id ?? fileName;
  }

  /// Listar todos los backups de proyectos
  Future<List<BackupInfo>> listProjectBackups() async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null || _backupFolderId == null) {
      return [];
    }

    try {
      final query =
          "'$_backupFolderId' in parents and name contains 'project_backup' and mimeType='application/zip' and trashed=false";
      final response = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        spaces: 'drive',
      );

      final backups = <BackupInfo>[];
      if (response.files != null) {
        for (final file in response.files!) {
          // Obtener tamaño del archivo
          int fileSize = 0;
          if (file.size != null && file.size!.isNotEmpty) {
            fileSize = int.tryParse(file.size!) ?? 0;
          } else {
            // Si el tamaño no está en el listado, obtenerlo del archivo completo
            try {
              if (file.id != null) {
                final fileDetails =
                    await _driveApi!.files.get(file.id!) as drive.File;
                if (fileDetails.size != null && fileDetails.size!.isNotEmpty) {
                  fileSize = int.tryParse(fileDetails.size!) ?? 0;
                }
              }
            } catch (e) {
              print(
                '⚠️ No se pudo obtener el tamaño del archivo ${file.name}: $e',
              );
            }
          }

          backups.add(
            BackupInfo(
              name: file.name ?? 'unknown',
              size: fileSize,
              created: file.createdTime ?? DateTime.now(),
              type: BackupType.project,
              driveFileId: file.id,
            ),
          );
        }
      }

      return backups;
    } catch (e) {
      print('❌ Error listando backups de proyectos: $e');
      rethrow;
    }
  }

  /// Descargar backup de proyecto (ZIP)
  /// Retorna los bytes del archivo ZIP
  Future<List<int>> downloadProjectBackup(String fileId) async {
    if (!isInitialized) {
      await initialize();
    }

    if (_driveApi == null) {
      throw Exception('Servicio no inicializado');
    }

    try {
      final media =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Leer el contenido como bytes
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      print(
        '✅ Backup de proyecto descargado: ${bytes.length} bytes (${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );
      return bytes;
    } catch (e) {
      print('❌ Error descargando backup de proyecto: $e');
      rethrow;
    }
  }

  /// Cerrar conexiones
  void dispose() {
    _authClient?.close();
    _driveApi = null;
    _authClient = null;
    _isInitialized = false;
  }
}

// BackupInfo y BackupType ahora están en ../models/backup_info.dart
