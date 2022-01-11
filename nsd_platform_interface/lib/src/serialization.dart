import 'dart:typed_data';
import 'dart:io';

import 'nsd_platform_interface.dart';
import 'utilities.dart';

String? deserializeString(arguments, String key) =>
    Map<String, dynamic>.from(arguments)[key];

Map<String, dynamic> serializeServiceType(String value) =>
    {'service.type': value};

Map<String, dynamic> serializeErrorCause(ErrorCause value) =>
    {'error.cause': enumValueToString(value)};

ErrorCause? deserializeErrorCause(dynamic arguments) {
  final errorCauseString = deserializeString(arguments, 'error.cause');
  if (errorCauseString == null) {
    return null;
  }

  return enumValueFromString(ErrorCause.values, errorCauseString);
}

Map<String, dynamic> serializeErrorMessage(String value) =>
    {'error.message': value};

String? deserializeErrorMessage(dynamic arguments) =>
    deserializeString(arguments, 'error.message');

NsdError? deserializeError(arguments) {
  final cause = deserializeErrorCause(arguments);
  final message = deserializeErrorMessage(arguments);
  if (cause == null || message == null) {
    return null;
  }
  return NsdError(cause, message);
}

Map<String, dynamic> serializeService(Service service) => {
      'service.name': service.name,
      'service.type': service.type,
      'service.host': service.host,
      'service.port': service.port,
      'service.txt': service.txt
    };

Service? deserializeService(dynamic arguments) {
  final data = Map<String, dynamic>.from(arguments);

  final name = data['service.name'] as String?;
  final type = data['service.type'] as String?;
  final host = data['service.host'] as String?;
  final port = data['service.port'] as int?;
  final txt = data['service.txt'] != null
      ? Map<String, Uint8List?>.from(data['service.txt'])
      : null;
  final addresses = data['service.addresses'] == null
      ? null
      : (data['service.addresses'] as List)
          .map((e) => InternetAddress(e.toString()))
          .toList();

  if (name == null &&
      type == null &&
      host == null &&
      port == null &&
      txt == null) {
    return null;
  }

  return Service(
      name: name,
      type: type,
      host: host,
      port: port,
      txt: txt,
      addresses: addresses);
}

Map<String, dynamic> serializeHandle(String value) => {
      'handle': value,
    };

String? deserializeHandle(dynamic arguments) =>
    deserializeString(arguments, 'handle');
