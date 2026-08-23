import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLog {
  const AppLog._();

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[fidel] WARN: $message${error == null ? '' : ' ($error)'}');
    }
    developer.log(
      message,
      name: 'fidel',
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
