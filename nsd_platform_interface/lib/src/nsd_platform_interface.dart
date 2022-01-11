import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

import 'method_channel_nsd_platform.dart';
import 'utilities.dart';

// Documentation: see the corresponding functions in the nsd main module.
abstract class NsdPlatformInterface extends PlatformInterface {
  NsdPlatformInterface() : super(token: _token);

  static final Object _token = Object();

  static NsdPlatformInterface _instance = MethodChannelNsdPlatform();

  static NsdPlatformInterface get instance => _instance;

  static set instance(NsdPlatformInterface instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Discovery> startDiscovery(String serviceType,
      {bool autoResolve = true});

  Future<void> stopDiscovery(Discovery discovery);

  Future<Service> resolve(Service service);

  Future<Registration> register(Service service);

  Future<void> unregister(Registration registration);

  void enableLogging(LogTopic logTopic);
}

/// Represents a network service.
class Service {
  const Service(
      {this.name, this.type, this.host, this.port, this.txt, this.addresses});

  final String? name;
  final String? type;
  final String? host;
  final int? port;
  final List<InternetAddress?>? addresses;

  /// Represents DNS TXT records.
  ///
  /// Keys MUST be printable US-ASCII values excluding '=', MUST be minimum 1
  /// and SHOULD be maximum 9 characters long.
  ///
  /// Values are opaque binary data (macOS, iOS) but some OS require the data
  /// to be convertible to UTF-8 (Android). Null is a valid value.
  /// Empty lists will be interpreted as null (macOS, iOS, Android).
  final Map<String, Uint8List?>? txt;

  @override
  String toString() =>
      'Service (name: $name, service type: $type, hostname: $host, port: $port, txt: $txt, addresses: $addresses)';
}

/// Returns true if the two [Service] instances refer to the same service.
bool isSame(Service a, Service b) => a.name == b.name && a.type == b.type;

/// Merges two [Service] by overwriting existing attributes where new
/// values are incoming.
Service merge(Service existing, Service incoming) => Service(
    name: incoming.name ?? existing.name,
    type: incoming.type ?? existing.type,
    host: incoming.host ?? existing.host,
    port: incoming.port ?? existing.port,
    txt: incoming.txt ?? existing.txt,
    addresses: incoming.addresses ?? existing.addresses);

/// Indicates the cause of an [NsdError].
enum ErrorCause {
  /// Indicates missing or invalid service name, type, host, port etc; in most
  /// cases this may be corrected by the client by changing these arguments.
  illegalArgument,

  /// Indicates too many "outstanding requests" - on Android (30) this seems
  /// to be 10 operations (running discoveries and active registrations
  /// combined).
  maxLimit,

  /// This error occurs on Android (seen on API 30) if too many resolve
  /// operations are requested simultanously. It should be prevented by the
  /// semaphore on the native side.
  alreadyActive,

  /// An error in platform or native code that cannot be adressed by the client.
  internalError,
}

/// Represents an error that occurred during an NSD operation.
///
/// Examine the [ErrorCause] to see wether or not the error can be adressed by the client.
class NsdError extends Error {
  final ErrorCause cause;
  final String message;

  // TODO hide this
  NsdError(this.cause, this.message);

  @override
  String toString() =>
      'NsdError (message: "$message", cause: ${enumValueToString(cause)})';
}

/// Represents a discovery.
///
/// It is also a [ChangeNotifier] so it can be used with a [ChangeNotifierProvider]
/// as described in the [Flutter Simple App State Management][1] chapter. The
/// plugin example app shows how to integrate this in a UI.
///
/// [1]: https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple#changenotifierprovider
class Discovery with ChangeNotifier {
  final String id;

  final List<Service> _services = [];

  /// The discovered services.
  ///
  /// This is updated when a new service is discovered or when a service
  /// is lost, as long as the discovery is running.
  List<Service> get services => List.unmodifiable(_services);

  // TODO hide this
  Discovery(this.id);

  // TODO hide this
  void add(Service service) {
    _services.add(service);
    notifyListeners();
  }

  // TODO hide this
  void remove(Service service) {
    _services.removeWhere((e) => isSame(e, service));
    notifyListeners();
  }

  @override
  String toString() => 'Discovery (id: $id, services: $services)';
}

/// Represents a registration.
class Registration {
  final String id;
  final Service service;

  // TODO hide this
  Registration(this.id, this.service);

  @override
  String toString() => 'Registration (id: $id, service: $service)';
}

/// Represents available log topics.
enum LogTopic {
  /// Logs calls to the native side and callbacks to the platform side.
  calls,

  /// Logs errors (enabled by default).
  errors
}
