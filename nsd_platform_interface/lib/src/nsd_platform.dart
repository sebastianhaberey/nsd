import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_nsd_platform.dart';
import 'utilities.dart';

/// Network Service Discovery (NSD) for Flutter.
abstract class NsdPlatform extends PlatformInterface {
  NsdPlatform() : super(token: _token);

  static final Object _token = Object();

  static NsdPlatform _instance = MethodChannelNsdPlatform();

  static NsdPlatform get instance => _instance;

  static set instance(NsdPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Starts a discovery for the specified service type.
  ///
  /// The Android documentation proposes resolving services just before
  /// connecting to them, but in many use cases the service host will be
  /// cruicial to decide on a service. For this reason, [autoResolve] is on by
  /// default and discovered services will be fully resolved.
  Future<Discovery> startDiscovery(String serviceType,
      {bool autoResolve = true});

  /// Stops the specified discovery.
  ///
  /// Discoveries must be stopped to free their resources. According to Android
  /// documentation, service discovery is an expensive operation, so it should
  /// be stopped when it's not needed any more, or when the application is
  /// paused.
  Future<void> stopDiscovery(Discovery discovery);

  /// Resolves the specified service.
  ///
  /// Unlike registration, resolving is usually quite fast.
  ///
  /// This method always returns a fresh [ServiceInfo] instance.
  Future<ServiceInfo> resolve(ServiceInfo serviceInfo);

  /// Registers a service as described by the service info.
  ///
  /// The requested name may be updated by the native side if there are name
  /// conflicts in the local network: "Service Name" -> "Service Name (2)" ->
  /// "Service Name (3)" etc, depending on availability.
  ///
  /// Registering might take a long time (observed on macOS / iOS) if the
  /// number of these retries is high. In this case, consider first discovering
  /// services, then pre-choosing an available name.
  Future<Registration> register(ServiceInfo serviceInfo);

  /// Services must be unregistered to free their resources.
  ///
  /// Unregistering your application when it closes down also helps prevent
  /// other applications from thinking it's still active and attempting to
  /// connect to it.
  Future<void> unregister(Registration registration);

  /// Enables logging for the specified topic.
  void enableLogging(LogTopic logTopic);
}

/// Represents
class ServiceInfo {
  const ServiceInfo({this.name, this.type, this.host, this.port, this.txt});

  final String? name;
  final String? type;
  final String? host;
  final int? port;

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
      'name: $name, service type: $type, hostname: $host, port: $port';
}

/// Returns true if the two [ServiceInfo] refer to the same service.
bool isSameService(ServiceInfo a, ServiceInfo b) {
  return a.name == b.name && a.type == b.type;
}

/// Merges two [ServiceInfo] by overwriting existing attributes where new
/// values are incoming.
ServiceInfo merge(ServiceInfo existing, ServiceInfo incoming) {
  return ServiceInfo(
      name: incoming.name ?? existing.name,
      type: incoming.type ?? existing.type,
      host: incoming.host ?? existing.host,
      port: incoming.port ?? existing.port,
      txt: incoming.txt ?? existing.txt);
}

enum ErrorCause {
  /// Indicates missing or invalid service name, type, host, port etc,
  /// may be corrected by the client.
  illegalArgument,

  /// This error occurs on Android (30) if too many resolve operations are
  /// requested simultanously. It should be prevented by the semaphore on the
  /// native side.
  alreadyActive,

  /// Indicates too many "outstanding requests" - on Android (30) this seems
  /// to be 10 operations (running discoveries and active registrations
  /// together).
  maxLimit,

  /// An error in platform or native code that cannot be adressed by the client.
  internalError,
}

/// Represents an error that occurred during an NSD operation.
///
/// NSD operations may throw an error that may or may not be adressed by the
/// client, depending on the cause.
class NsdError extends Error {
  final ErrorCause cause;
  final String message;

  NsdError(this.cause, this.message);

  @override
  String toString() => '$message (${enumValueToString(cause)})';
}

/// Represents an ongoing discovery.
class Discovery with ChangeNotifier {
  final String id;

  Discovery(this.id);

  final List<ServiceInfo> _serviceInfos = [];

  List<ServiceInfo> get serviceInfos => List.unmodifiable(_serviceInfos);

  void add(ServiceInfo serviceInfo) {
    _serviceInfos.add(serviceInfo);
    notifyListeners();
  }

  void remove(ServiceInfo serviceInfo) {
    _serviceInfos.removeWhere((e) => isSameService(e, serviceInfo));
    notifyListeners();
  }
}

/// Represents an active registration.
class Registration {
  final String id;
  final ServiceInfo serviceInfo;

  Registration(this.id, this.serviceInfo);
}

/// List of available log topics.
///
/// The error topic is enabled by default, all others may be enabled by
/// the user.
enum LogTopic { calls, errors }
