import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
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
      {bool autoResolve = true, IpLookupType ipLookupType = IpLookupType.none});

  Future<void> stopDiscovery(Discovery discovery);

  Future<Service> resolve(Service service);

  Future<Registration> register(Service service);

  Future<void> unregister(Registration registration);

  void enableLogging(LogTopic logTopic);

  void disableServiceTypeValidation(bool value);
}

/// Represents a network service.
class Service {
  const Service(
      {this.name, this.type, this.host, this.port, this.txt, this.addresses});

  final String? name;
  final String? type;
  final String? host;
  final int? port;
  final List<InternetAddress>? addresses;

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
  /// operations are requested simultaneously. It should be prevented by the
  /// semaphore on the native side.
  alreadyActive,

  /// An error in platform or native code that cannot be addressed by the client.
  internalError,

  /// The operation is not supported, for example if the OS version is not
  /// recent enough and doesn't support mDNS / DNS-SD API.
  operationNotSupported,

  /// A security issue, for example a missing permission.
  securityIssue,
}

/// Represents an error that occurred during an NSD operation.
///
/// Examine the [ErrorCause] to see whether or not the error can be addressed by the client.
class NsdError extends Error {
  final ErrorCause cause;
  final String message;

  // TODO hide this
  NsdError(this.cause, this.message);

  @override
  String toString() =>
      'NsdError (message: "$message", cause: ${enumValueToString(cause)})';
}

/// Indicates the discovery status of a service.
enum ServiceStatus {
  /// Service was found
  found,

  /// Service was lost
  lost,
}

typedef ServiceListener = FutureOr<void> Function(
    Service service, ServiceStatus status);

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
  final List<ServiceListener> _serviceListeners = [];

  /// The discovered services.
  ///
  /// This is updated when a new service is discovered or when a service
  /// is lost, as long as the discovery is running.
  List<Service> get services => List.unmodifiable(_services);

  // TODO hide this
  Discovery(this.id);

  // TODO hide this
  void add(Service service) {
    final existing = _services.firstWhereOrNull((e) => isSame(e, service));
    if (existing == null) {
      _services.add(service);
      _notifyAllListeners(service, ServiceStatus.found);
    }
  }

  // TODO hide this
  void remove(Service service) {
    final existing = _services.firstWhereOrNull((e) => isSame(e, service));
    if (existing != null) {
      _services.remove(existing);
      _notifyAllListeners(existing, ServiceStatus.lost);
    }
  }

  /// Adds a listener that is notified when a new service is found
  /// or an existing one is lost.
  void addServiceListener(ServiceListener serviceListener) {
    _serviceListeners.add(serviceListener);
  }

  void removeServiceListener(ServiceListener serviceListener) {
    _serviceListeners.remove(serviceListener);
  }

  void _notifyAllListeners(Service service, ServiceStatus status) {
    notifyListeners();
    for (var serviceListener in _serviceListeners) {
      serviceListener(service, status);
    }
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

  /// Logs errors.
  errors
}

/// Configures IP lookup.
///
/// Since IP lookup is performed using the service host name,
/// auto resolving must be enabled for IP lookup.
enum IpLookupType {
  /// Don't perform IP lookup
  none,

  /// Look up IP v4 addresses only
  v4,

  /// Look up IP v6 addresses only
  v6,

  /// Look up all types of IP addresses
  any,
}
