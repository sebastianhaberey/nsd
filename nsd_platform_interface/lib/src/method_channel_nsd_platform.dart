import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'logging.dart';
import 'nsd_platform_interface.dart';
import 'serialization.dart';

typedef _Handler = void Function(dynamic);

const _uuid = Uuid();

/// Implementation of [NsdPlatformInterface] that uses a method channel to communicate with native side.
class MethodChannelNsdPlatform extends NsdPlatformInterface {
  final _methodChannel = const MethodChannel('com.haberey/nsd');
  final _handlers = <String, Map<String, _Handler>>{};

  MethodChannelNsdPlatform() {
    _methodChannel.setMethodCallHandler(handleMethodCall);
  }

  @override
  Future<Discovery> startDiscovery(String serviceType,
      {bool autoResolve = true}) async {
    assertValidServiceType(serviceType);

    final handle = _uuid.v4();
    final discovery = Discovery(handle);

    final completer = Completer<Discovery>();
    _attachDummyCallback(completer.future);

    setHandler(handle, 'onDiscoveryStartSuccessful',
        (arguments) => completer.complete(discovery));

    setHandler(handle, 'onDiscoveryStartFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    setHandler(handle, 'onServiceDiscovered', (arguments) async {
      discovery.add(autoResolve
          ? await resolve(deserializeService(arguments)!)
          : deserializeService(arguments)!);
    });

    setHandler(handle, 'onServiceLost',
        (arguments) => discovery.remove(deserializeService(arguments)!));

    return invoke('startDiscovery', {
      ...serializeHandle(handle),
      ...serializeServiceType(serviceType)
    }).then((value) => completer.future);
  }

  @override
  Future<void> stopDiscovery(Discovery discovery) async {
    final completer = Completer<void>();
    _attachDummyCallback(completer.future);
    final handle = discovery.id;

    setHandler(handle, 'onDiscoveryStopSuccessful', (arguments) {
      discardHandlers(handle);
      completer.complete();
    });

    setHandler(handle, 'onDiscoveryStopFailed', (arguments) {
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

    setHandler(handle, 'onResolveSuccessful', (arguments) {
      discardHandlers(handle);
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(service, deserializeService(arguments)!);
      completer.complete(merged);
    });

    setHandler(handle, 'onResolveFailed', (arguments) {
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

    setHandler(handle, 'onRegistrationSuccessful', (arguments) {
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(service, deserializeService(arguments)!);
      completer.complete(Registration(handle, merged));
    });

    setHandler(handle, 'onRegistrationFailed', (arguments) {
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

    setHandler(handle, 'onUnregistrationSuccessful', (arguments) {
      discardHandlers(handle);
      completer.complete();
    });

    setHandler(handle, 'onUnregistrationFailed', (arguments) {
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

    final handler = getHandler(handle, method);
    if (handler == null) {
      throw NsdError(ErrorCause.internalError, 'No handler: $method $handle');
    }

    return handler(arguments);
  }

  _Handler? getHandler(String handle, String method) {
    return _handlers[handle]?[method];
  }

  Future<void> invoke(String method, [dynamic arguments]) {
    log(this, LogTopic.calls, () => 'Call: $method $arguments');
    return _methodChannel.invokeMethod(method, arguments);
  }

  void setHandler(String handle, String method, _Handler handler) {
    _handlers.putIfAbsent(handle, () => {})[method] = handler;
  }

  void discardHandlers(String handle) {
    _handlers.remove(handle);
  }

  @override
  void enableLogging(LogTopic logTopic) {
    enableLogTopic(logTopic);
  }
}

// prevent the future from throwing uncaught error due to missing callback
// https://stackoverflow.com/a/66481566/8707976
void _attachDummyCallback<T>(Future<T> future) => unawaited(
    future.then<void>((value) => null).onError((error, stackTrace) => null));

void assertValidServiceType(String? serviceType) {
  if (!isValidServiceType(serviceType)) {
    throw NsdError(ErrorCause.illegalArgument,
        'Service type must be in format _<Service>._<Proto>: $serviceType');
  }
}

bool isValidServiceType(String? type) {
  // <Service> portion
  //
  // first label see https://www.rfc-editor.org/rfc/rfc6335.html (5.1):
  //
  // - MUST be at least 1 character and no more than 15 characters long
  // - MUST contain only  'A' - 'Z', 'a' - 'z', '0' - '9', hyphens
  // - MUST contain at least one letter
  //
  // second label see https://datatracker.ietf.org/doc/html/rfc6763#section-4.1.2:
  //
  //  -  either "_tcp" or "_udp"

  if (type == null) {
    return false;
  }

  if (type == '_services._dns-sd._udp') {
    return true; // special type for enumeration of services, see https://datatracker.ietf.org/doc/html/rfc6763#section-9 (issue #8)
  }

  return RegExp(r'^_[a-zA-Z0-9-]{1,15}._(tcp|udp)').hasMatch(type);
}
