import 'package:nsd_platform_interface/nsd_platform_interface.dart';

export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show Service;
export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show Discovery;
export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show Registration;
export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show ErrorCause;
export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show NsdError;
export 'package:nsd_platform_interface/nsd_platform_interface.dart'
    show LogTopic;

/// Starts a discovery for the specified service type.
///
/// The Android documentation proposes resolving services just before
/// connecting to them, but in many use cases the service host will be
/// cruicial to decide on a service. For this reason, [autoResolve] is on by
/// default and discovered services will be fully resolved.
Future<Discovery> startDiscovery(String serviceType,
        {bool autoResolve = true}) async =>
    NsdPlatformInterface.instance
        .startDiscovery(serviceType, autoResolve: autoResolve);

/// Stops the specified discovery.
///
/// Discoveries must be stopped to free their resources. According to Android
/// documentation, service discovery is an expensive operation, so it should
/// be stopped when it's not needed any more, or when the application is
/// paused.
Future<void> stopDiscovery(Discovery discovery) {
  return NsdPlatformInterface.instance.stopDiscovery(discovery);
}

/// Resolves a service.
///
/// Unlike registration, resolving is usually quite fast.
///
/// This method always returns a fresh [Service] instance.
Future<Service> resolve(Service service) async =>
    NsdPlatformInterface.instance.resolve(service);

/// Registers a service.
///
/// The requested name may be updated by the native side if there are name
/// conflicts in the local network: "Service Name" -> "Service Name (2)" ->
/// "Service Name (3)" etc, depending on availability.
///
/// Registering might take a long time (observed on macOS / iOS) if the
/// number of these retries is high. In this case, consider first discovering
/// services, then pre-choosing an available name.
Future<Registration> register(Service service) async =>
    NsdPlatformInterface.instance.register(service);

/// Unregisters a service.
///
/// Services must be unregistered to free their resources. Unregistering a
/// service when it closes down also helps prevent other applications from
/// thinking it's still active and attempting to connect to it.
Future<void> unregister(Registration registration) async =>
    NsdPlatformInterface.instance.unregister(registration);

/// Enables logging for the specified topic.
///
void enableLogging(LogTopic logTopic) =>
    NsdPlatformInterface.instance.enableLogging(logTopic);
