/// Centralized logging abstraction for VendingApp.
///
/// Never log access tokens, passwords, id tokens, or other secrets.
abstract interface class AppLogger {
  void debug(String message, {Map<String, Object?>? context});

  void info(String message, {Map<String, Object?>? context});

  void warning(String message, {Map<String, Object?>? context});

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });
}

enum LogLevel { debug, info, warning, error }

/// Console logger with a configurable minimum level.
final class ConsoleAppLogger implements AppLogger {
  ConsoleAppLogger({this.minimumLevel = LogLevel.debug});

  final LogLevel minimumLevel;

  @override
  void debug(String message, {Map<String, Object?>? context}) {
    _log(LogLevel.debug, message, context: context);
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    _log(LogLevel.info, message, context: context);
  }

  @override
  void warning(String message, {Map<String, Object?>? context}) {
    _log(LogLevel.warning, message, context: context);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _log(
      LogLevel.error,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) {
      return;
    }
    final buffer = StringBuffer('[${level.name.toUpperCase()}] $message');
    final safeContext = sanitizeLogContext(context);
    if (safeContext != null && safeContext.isNotEmpty) {
      buffer.write(' $safeContext');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    // ignore: avoid_print
    print(buffer.toString());
    if (stackTrace != null && level == LogLevel.error) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }
}

/// Removes known sensitive keys from log context maps.
Map<String, Object?>? sanitizeLogContext(Map<String, Object?>? context) {
  if (context == null) {
    return null;
  }

  const sensitive = {
    'authorization',
    'access_token',
    'refresh_token',
    'id_token',
    'password',
    'secret',
    'token',
  };

  return Map<String, Object?>.fromEntries(
    context.entries.where((entry) {
      final key = entry.key.toLowerCase();
      return !sensitive.contains(key) &&
          !key.contains('token') &&
          !key.contains('password') &&
          !key.contains('secret');
    }),
  );
}
