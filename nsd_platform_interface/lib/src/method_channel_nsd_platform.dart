import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nsd_platform_interface/src/utilities.dart';
import 'package:uuid/uuid.dart';

import 'logging.dart';
import 'nsd_platform_interface.dart';
import 'serialization.dart';

typedef _Handler = void Function(dynamic);

const _uuid = Uuid();

const _ipLookupTypeToInternetAddressType = {
  IpLookupType.none: null,
  IpLookupType.v4: InternetAddressType.IPv4,
  IpLookupType.v6: InternetAddressType.IPv6,
  IpLookupType.any: InternetAddressType.any,
};

/// Implementation of [NsdPlatformInterface] that uses a method channel to communicate with native side.
class MethodChannelNsdPlatform extends NsdPlatformInterface {
  final _methodChannel = const MethodChannel('com.haberey/nsd');
  final _handlers = <String, Map<String, _Handler>>{};

  var _disableServiceTypeValidation = false;

  MethodChannelNsdPlatform() {
    _methodChannel.setMethodCallHandler(handleMethodCall);
  }

  @override
  Future<Discovery> startDiscovery(String serviceType,
      {bool autoResolve = true,
      IpLookupType ipLookupType = IpLookupType.none}) async {
    assertValidServiceType(serviceType);

    if (isIpLookupEnabled(ipLookupType) && autoResolve == false) {
      throw NsdError(ErrorCause.illegalArgument,
          'Auto resolve must be enabled for IP lookup');
    }

    final handle = _uuid.v4();
    final discovery = Discovery(handle);

    final completer = Completer<Discovery>();
    _attachDummyCallback(completer.future);

    _setHandler(handle, 'onDiscoveryStartSuccessful',
        (arguments) => completer.complete(discovery));

    _setHandler(handle, 'onDiscoveryStartFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    _setHandler(handle, 'onServiceDiscovered', (arguments) async {
      var service = deserializeService(arguments)!;
      if (autoResolve) {
        service = await resolve(service);

        // TODO remove this and deprecate IpLookupType once Windows supports native addresses too
        service = await performIpLookup(service, ipLookupType);
      }
      discovery.add(service);
    });

    _setHandler(handle, 'onServiceLost',
        (arguments) => discovery.remove(deserializeService(arguments)!));

    return invoke('startDiscovery', {
      ...serializeHandle(handle),
      ...serializeServiceType(serviceType)
    }).then((value) => completer.future);
  }

  Future<Service> performIpLookup(
      Service service, IpLookupType ipLookupType) async {
    final internetAddressType = getInternetAddressType(ipLookupType);
    if (internetAddressType == null) {
      return service; // lookup not enabled -> leave service as is
    }

    var addresses = service.addresses;
    if (addresses != null && internetAddressType != InternetAddressType.any) {
      // platform already supplied addresses -> no lookup, but respect user's choice of address type
      addresses =
          addresses.where((a) => a.type == internetAddressType).toList();
    } else {
      final host = service.host;
      if (host == null) {
        return service; // cannot look up addresses -> leave service as is
      }
      addresses = await InternetAddress.lookup(host, type: internetAddressType);
    }

    return merge(service, Service(addresses: addresses));
  }

  @override
  Future<void> stopDiscovery(Discovery discovery) async {
    final completer = Completer<void>();
    _attachDummyCallback(completer.future);
    final handle = discovery.id;

    _setHandler(handle, 'onDiscoveryStopSuccessful', (arguments) {
      discardHandlers(handle);
      completer.complete();
    });

    _setHandler(handle, 'onDiscoveryStopFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('stopDiscovery', {...serializeHandle(handle)})
        .then((value) => completer.future);
  }

  @override
  Future<Service> resolve(Service service) async {
    assertValidServiceType(service.type);

    final handle = _uuid.v4();

    final completer = Completer<Service>();
    _attachDummyCallback(completer.future);

    _setHandler(handle, 'onResolveSuccessful', (arguments) {
      discardHandlers(handle);
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(service, deserializeService(arguments)!);
      completer.complete(merged);
    });

    _setHandler(handle, 'onResolveFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('resolve', {
      ...serializeHandle(handle),
      ...serializeService(service),
    }).then((value) => completer.future);
  }

  @override
  Future<Registration> register(Service service) async {
    assertValidServiceType(service.type);

    final handle = _uuid.v4();
    final completer = Completer<Registration>();
    _attachDummyCallback(completer.future);

    _setHandler(handle, 'onRegistrationSuccessful', (arguments) {
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(service, deserializeService(arguments)!);
      completer.complete(Registration(handle, merged));
    });

    _setHandler(handle, 'onRegistrationFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('register', {
      ...serializeHandle(handle),
      ...serializeService(service),
    }).then((value) => completer.future);
  }

  @override
  Future<void> unregister(Registration registration) async {
    final completer = Completer<void>();
    _attachDummyCallback(completer.future);
    final handle = registration.id;

    _setHandler(handle, 'onUnregistrationSuccessful', (arguments) {
      discardHandlers(handle);
      completer.complete();
    });

    _setHandler(handle, 'onUnregistrationFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('unregister', serializeHandle(handle))
        .then((value) => completer.future);
  }

  Future<dynamic> handleMethodCall(MethodCall methodCall) async {
    final method = methodCall.method;
    final arguments = methodCall.arguments;

    log(this, LogTopic.calls, () => 'Callback: $method $arguments');

    final handle = deserializeHandle(arguments);
    if (handle == null) {
      throw NsdError(ErrorCause.illegalArgument, 'Expected handle');
    }

    final handler = _getHandler(handle, method);
    if (handler == null) {
      throw NsdError(ErrorCause.internalError, 'No handler: $method $handle');
    }

    return handler(arguments);
  }

  _Handler? _getHandler(String handle, String method) {
    return _handlers[handle]?[method];
  }

  Future<void> invoke(String method, [dynamic arguments]) {
    log(this, LogTopic.calls, () => 'Call: $method $arguments');
    return _methodChannel
        .invokeMethod(method, arguments)
        .catchError((e) => throw toNsdError(e));
  }

  void _setHandler(String handle, String method, _Handler handler) {
    _handlers.putIfAbsent(handle, () => {})[method] = handler;
  }

  void discardHandlers(String handle) {
    _handlers.remove(handle);
  }

  @override
  void enableLogging(LogTopic logTopic) {
    enableLogTopic(logTopic);
  }

  @override
  void disableServiceTypeValidation(bool value) {
    _disableServiceTypeValidation = value;
  }

  void assertValidServiceType(String? serviceType) {
    if (!_disableServiceTypeValidation && !isValidServiceType(serviceType)) {
      throw NsdError(ErrorCause.illegalArgument,
          'Service type must be in format _<Service>._<Proto>: $serviceType');
    }
  }
}

Future<Service> performIpLookup(
    Service service, InternetAddressType internetAddressType) async {
  final host = service.host;

  if (host == null) {
    return service;
  }

  final addresses =
      await InternetAddress.lookup(host, type: internetAddressType);
  return merge(service, Service(addresses: addresses));
}

// prevent the future from throwing uncaught error due to missing callback
// https://stackoverflow.com/a/66481566/8707976
void _attachDummyCallback<T>(Future<T> future) => unawaited(
    future.then<void>((value) => null).onError((error, stackTrace) => null));

bool isValidServiceType(String? type) {
  if (type == null) {
    return false;
  }

  if (type == '_services._dns-sd._udp') {
    return true; // special type for enumeration of services, see https://datatracker.ietf.org/doc/html/rfc6763#section-9 (issue #8)
  }

  return RegExp(r'^_[a-zA-Z0-9-]{1,15}._(tcp|udp)').hasMatch(type);
}

InternetAddressType? getInternetAddressType(IpLookupType ipLookupType) {
  return _ipLookupTypeToInternetAddressType[ipLookupType];
}

bool isIpLookupEnabled(IpLookupType ipLookupType) {
  return ipLookupType != IpLookupType.none;
}

NsdError toNsdError(Exception e) {
  if (e is! PlatformException) {
    return NsdError(ErrorCause.internalError, e.toString());
  }

  final message = e.message ?? '';
  final errorCode = enumValueFromString(ErrorCause.values, e.code);

  if (errorCode == null) {
    return NsdError(ErrorCause.internalError, message);
  }

  return NsdError(errorCode, message);
}
