import 'dart:developer' as developer;

void log(Object source, String message, {StackTrace? stackTrace}) {
  final name = source.runtimeType.toString();
  developer.log(message, name: name, stackTrace: stackTrace);
}

void logDebug(Object source, String message, {StackTrace? stackTrace}) {
  log(source, '[DEBUG]: $message');
}

void logInfo(Object source, String message, {StackTrace? stackTrace}) {
  log(source, '[INFO]: $message');
}

void logWarning(Object source, String message, {StackTrace? stackTrace}) {
  log(source, '[WARNING]: $message');
}

void logError(Object source, String message, {StackTrace? stackTrace}) {
  log(source, '[ERROR]: $message');
}
