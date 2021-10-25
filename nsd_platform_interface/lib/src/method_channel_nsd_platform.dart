import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nsd_platform_interface/src/logging.dart';
import 'package:uuid/uuid.dart';

import 'nsd_platform.dart';
import 'serialization.dart';

typedef _Handler = void Function(dynamic);

const _uuid = Uuid();

// prevent the future from throwing uncaught error due to missing callback
// https://stackoverflow.com/a/66481566/8707976
void _attachDummyCallback<T>(Future<T> future) => unawaited(
    future.then<void>((value) => null).onError((error, stackTrace) => null));

/// Implementation of [NsdPlatform] that uses a method channel to communicate with native side.
class MethodChannelNsdPlatform extends NsdPlatform {
  final _methodChannel = const MethodChannel('com.haberey/nsd');
  final _handlers = <String, Map<String, _Handler>>{};

  MethodChannelNsdPlatform() {
    _methodChannel.setMethodCallHandler(handleMethodCall);
  }

  @override
  Future<Discovery> startDiscovery(String serviceType,
      {bool autoResolve = true}) async {
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
          ? await resolve(deserializeServiceInfo(arguments)!)
          : deserializeServiceInfo(arguments)!);
    });

    setHandler(handle, 'onServiceLost',
        (arguments) => discovery.remove(deserializeServiceInfo(arguments)!));

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
  Future<ServiceInfo> resolve(ServiceInfo serviceInfo) async {
    final handle = _uuid.v4();

    final completer = Completer<ServiceInfo>();
    _attachDummyCallback(completer.future);

    setHandler(handle, 'onResolveSuccessful', (arguments) {
      discardHandlers(handle);
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(serviceInfo, deserializeServiceInfo(arguments)!);
      completer.complete(merged);
    });

    setHandler(handle, 'onResolveFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('resolve', {
      ...serializeHandle(handle),
      ...serializeServiceInfo(serviceInfo),
    }).then((value) => completer.future);
  }

  @override
  Future<Registration> register(ServiceInfo serviceInfo) async {
    final handle = _uuid.v4();
    final completer = Completer<Registration>();
    _attachDummyCallback(completer.future);

    setHandler(handle, 'onRegistrationSuccessful', (arguments) {
      // merge received service info into requested service info b/c some
      // properties may have been updated, but the received service info isn't
      // always complete, e.g. NetService only returns the name
      final merged = merge(serviceInfo, deserializeServiceInfo(arguments)!);
      completer.complete(Registration(handle, merged));
    });

    setHandler(handle, 'onRegistrationFailed', (arguments) {
      discardHandlers(handle);
      completer.completeError(deserializeError(arguments)!);
    });

    return invoke('register', {
      ...serializeHandle(handle),
      ...serializeServiceInfo(serviceInfo),
    }).then((value) => completer.future);
  }

  @override
  Future<void> unregister(Registration registration) async {
    final completer = Completer<void>();
    _attachDummyCallback(completer.future);
    final handle = registration.id;

    setHandler(handle, 'onUnregistrationSuccessful',
        (arguments) => completer.complete());

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

    logDebug(this, 'Callback: $method $arguments');

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
    logDebug(this, 'Call: $method $arguments');
    return _methodChannel.invokeMethod(method, arguments);
  }

  void setHandler(String handle, String method, _Handler handler) {
    _handlers.putIfAbsent(handle, () => {})[method] = handler;
  }

  void discardHandlers(String handle) {
    _handlers.remove(handle);
  }
}
