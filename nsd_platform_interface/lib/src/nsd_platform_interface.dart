import 'dart:typed_data';

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

  Future<ServiceInfo> resolve(ServiceInfo serviceInfo);

  Future<Registration> register(ServiceInfo serviceInfo);

  Future<void> unregister(Registration registration);

  void enableLogging(LogTopic logTopic);
}

/// Represents a network service.
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

  NsdError(this.cause, this.message);

  @override
  String toString() => '$message (${enumValueToString(cause)})';
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

  Discovery(this.id);

  final List<ServiceInfo> _serviceInfos = [];

  List<ServiceInfo> get services => List.unmodifiable(_serviceInfos);

  void add(ServiceInfo serviceInfo) {
    _serviceInfos.add(serviceInfo);
    notifyListeners();
  }

  void remove(ServiceInfo serviceInfo) {
    _serviceInfos.removeWhere((e) => isSameService(e, serviceInfo));
    notifyListeners();
  }
}

/// Represents a registration.
class Registration {
  final String id;
  final ServiceInfo serviceInfo;

  Registration(this.id, this.serviceInfo);
}

/// Available log topics.
///
/// The error topic is enabled by default, all others may be enabled by the user.
enum LogTopic { calls, errors }
