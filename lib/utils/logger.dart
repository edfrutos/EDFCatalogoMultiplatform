import 'package:flutter/foundation.dart';

/// Utilidad para logging condicional
/// Solo imprime en modo debug, no en producción
class Logger {
  static const bool _enableDebug = kDebugMode;

  static void debug(String message) {
    if (_enableDebug) {
      print('🔍 [DEBUG] $message');
    }
  }

  static void info(String message) {
    if (_enableDebug) {
      print('ℹ️ [INFO] $message');
    }
  }

  static void success(String message) {
    if (_enableDebug) {
      print('✅ [SUCCESS] $message');
    }
  }

  static void warning(String message) {
    if (_enableDebug) {
      print('⚠️ [WARNING] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enableDebug) {
      print('❌ [ERROR] $message');
      if (error != null) {
        print('   Error: $error');
      }
      if (stackTrace != null) {
        print('   StackTrace: $stackTrace');
      }
    }
  }

  // Método para logs críticos que siempre se muestran (incluso en producción)
  static void critical(String message, [Object? error]) {
    print('🚨 [CRITICAL] $message');
    if (error != null) {
      print('   Error: $error');
    }
  }
}
