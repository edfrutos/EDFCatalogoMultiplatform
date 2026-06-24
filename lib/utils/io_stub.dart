// Stub completo de dart:io para compilación en Flutter Web.
// Se usa con el import condicional:
//   import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
//
// Los métodos devuelven valores vacíos/neutros — en producción nunca se
// llaman porque todo el código nativo está guardado con kIsWeb.

// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:async';
import 'dart:typed_data';

// ── FileStat ──────────────────────────────────────────────────────────────────

class FileStat {
  final int size;
  final DateTime modified;
  final DateTime accessed;
  final DateTime changed;
  FileStat._({
    this.size = 0,
    DateTime? modified,
    DateTime? accessed,
    DateTime? changed,
  })  : modified = modified ?? DateTime(0),
        accessed = accessed ?? DateTime(0),
        changed = changed ?? DateTime(0);
}

// ── FileSystemEntity ──────────────────────────────────────────────────────────

abstract class FileSystemEntity {
  String get path;
  Future<bool> exists() async => false;
  Future<void> delete({bool recursive = false}) async {}
  Future<FileStat> stat() async => FileStat._();
  static Future<bool> isDirectory(String path) async => false;
  static Future<bool> isFile(String path) async => false;
}

// ── File ──────────────────────────────────────────────────────────────────────

class File extends FileSystemEntity {
  @override
  final String path;
  File(this.path);

  // Async
  @override
  Future<bool> exists() async => false;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<String> readAsString(
          {Encoding encoding = const Utf8Codec()}) async =>
      '';
  Future<List<String>> readAsLines() async => [];
  Future<int> length() async => 0;
  Future<File> writeAsBytes(List<int> bytes,
      {FileMode mode = FileMode.write}) async => this;
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write}) async => this;
  Future<File> create({bool recursive = false}) async => this;
  @override
  Future<void> delete({bool recursive = false}) async {}
  Future<File> copy(String newPath) async => File(newPath);

  // Sync
  bool existsSync() => false;
  Uint8List readAsBytesSync() => Uint8List(0);
  String readAsStringSync({Encoding encoding = const Utf8Codec()}) => '';
  List<String> readAsLinesSync() => [];
  int lengthSync() => 0;
  void writeAsBytesSync(List<int> bytes,
      {FileMode mode = FileMode.write}) {}
  void writeAsStringSync(String contents,
      {FileMode mode = FileMode.write}) {}
  void createSync({bool recursive = false}) {}
  void deleteSync({bool recursive = false}) {}

  // Properties
  Directory get parent {
    final idx = path.lastIndexOf('/');
    return Directory(idx >= 0 ? path.substring(0, idx) : '.');
  }
}

// ── Directory ─────────────────────────────────────────────────────────────────

class Directory extends FileSystemEntity {
  @override
  final String path;
  Directory(this.path);

  // Static
  static Directory get current => Directory('.');
  static Directory get systemTemp => Directory('/tmp');

  // Async
  @override
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  @override
  Future<void> delete({bool recursive = false}) async {}
  Stream<FileSystemEntity> list(
          {bool recursive = false, bool followLinks = true}) =>
      const Stream.empty();
  Future<Directory> createTemp([String? prefix]) async =>
      Directory('$path/tmp');

  // Sync
  bool existsSync() => false;
  void createSync({bool recursive = false}) {}
  void deleteSync({bool recursive = false}) {}
  List<FileSystemEntity> listSync(
          {bool recursive = false, bool followLinks = true}) =>
      [];

  // Properties
  Directory get parent {
    final idx = path.lastIndexOf('/');
    return Directory(idx >= 0 ? path.substring(0, idx) : '.');
  }
}

// ── FileMode ──────────────────────────────────────────────────────────────────

class FileMode {
  static const FileMode read = FileMode._('read');
  static const FileMode write = FileMode._('write');
  static const FileMode append = FileMode._('append');
  static const FileMode writeOnly = FileMode._('writeOnly');
  final String _name;
  const FileMode._(this._name);
  @override
  String toString() => 'FileMode.$_name';
}

// ── Encoding (minimal) ────────────────────────────────────────────────────────

abstract class Encoding {
  const Encoding();
  String get name;
}

class Utf8Codec extends Encoding {
  const Utf8Codec();
  @override
  String get name => 'utf-8';
}

// ── Platform ──────────────────────────────────────────────────────────────────

class Platform {
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isFuchsia => false;
  static String get operatingSystem => 'web';
  static Map<String, String> get environment => {};
  static String get executable => '';
  static List<String> get executableArguments => [];
  static String? get packageConfig => null;
  static String get resolvedExecutable => '';
  static Uri get script => Uri();
  static String get localHostname => 'localhost';
  static int get numberOfProcessors => 1;
  static String get pathSeparator => '/';
  static String get version => '0.0.0';
}

// ── Process ───────────────────────────────────────────────────────────────────

class ProcessResult {
  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}

class Process {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async =>
      ProcessResult(0, 1, '', 'Unsupported on web');

  static Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async =>
      throw UnsupportedError('Process.start not supported on web');
}

// ── ContentType ───────────────────────────────────────────────────────────────

class ContentType {
  static const ContentType html =
      ContentType._('text/html', 'charset=utf-8');
  static const ContentType json =
      ContentType._('application/json', 'charset=utf-8');
  static const ContentType text =
      ContentType._('text/plain', 'charset=utf-8');
  static const ContentType binary =
      ContentType._('application/octet-stream', '');
  final String _primaryType;
  final String _parameters;
  const ContentType._(this._primaryType, this._parameters);
  @override
  String toString() => '$_primaryType; $_parameters';
}

// ── HttpHeaders ───────────────────────────────────────────────────────────────

class HttpHeaders {
  ContentType? contentType;
  void set(String name, Object value) {}
  List<String>? operator [](String name) => null;
}

// ── HttpResponse ──────────────────────────────────────────────────────────────

class HttpResponse {
  int statusCode = 200;
  final HttpHeaders headers = HttpHeaders();
  void write(Object? obj) {}
  void writeln([Object? obj = '']) {}
  void add(List<int> data) {}
  Future<void> close() async {}
}

// ── HttpRequest ───────────────────────────────────────────────────────────────

class HttpRequest {
  Uri get uri => Uri();
  Uri get requestedUri => Uri();
  String get method => 'GET';
  final HttpResponse response = HttpResponse();
  Stream<List<int>> get asBroadcastStream => const Stream.empty();
}

// ── HttpServer ────────────────────────────────────────────────────────────────

class HttpServer extends Stream<HttpRequest> {
  static Future<HttpServer> bind(dynamic address, int port,
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false}) async =>
      throw UnsupportedError('HttpServer not supported on web');

  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      throw UnsupportedError('HttpServer not supported on web');

  Future<void> close({bool force = false}) async {}
}

// ── IOSink (stdout / stderr stub) ─────────────────────────────────────────────

class IOSink {
  void write(Object? obj) {}
  void writeln([Object? obj = '']) {}
  void writeAll(Iterable objects, [String separator = '']) {}
  void add(List<int> data) {}
  Future<void> flush() async {}
  Future<void> close() async {}
}

// ignore: non_constant_identifier_names
final IOSink stdout = IOSink();
// ignore: non_constant_identifier_names
final IOSink stderr = IOSink();
