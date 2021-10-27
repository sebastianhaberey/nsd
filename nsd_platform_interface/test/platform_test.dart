import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_platform_interface/src/method_channel_nsd_platform.dart';
import 'package:nsd_platform_interface/src/nsd_platform_interface.dart';
import 'package:nsd_platform_interface/src/serialization.dart';

const channelName = 'com.haberey/nsd';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelNsdPlatform _nsd;
  late MethodChannel _methodChannel;
  late Map<String, Function(String handle, dynamic arguments)> _mockHandlers;

  setUp(() async {
    _nsd = MethodChannelNsdPlatform();
    _nsd.enableLogging(LogTopic.calls);
    _methodChannel = const MethodChannel(channelName);
    _mockHandlers = HashMap();

    // install custom handler that routes method calls to mock handlers
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel,
            (MethodCall methodCall) async {
      final handle = deserializeHandle(methodCall.arguments)!;
      _mockHandlers[methodCall.method]?.call(handle, methodCall.arguments);
    });
  });

  group('$MethodChannelNsdPlatform discovery', () {
    test('Start succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      await _nsd.startDiscovery('foo');
    });

    test('Start fails if native code reports failure', () async {
      // simulate failure callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.startDiscovery('foo'), throwsA(matcher));
    });

    test('Stop succeeds if native code reports success', () async {
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      _mockHandlers['stopDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStopSuccessful', serializeHandle(handle));
      };

      final discovery = await _nsd.startDiscovery('foo');
      await _nsd.stopDiscovery(discovery);
    });

    test('Stop fails if native code reports failure', () async {
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      _mockHandlers['stopDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStopFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      final discovery = await _nsd.startDiscovery('foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.stopDiscovery(discovery), throwsA(matcher));
    });

    test('Client is notified if service is discovered', () async {
      late String capturedHandle;

      _mockHandlers['startDiscovery'] = (handle, arguments) {
        capturedHandle = handle;
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      final discovery = await _nsd.startDiscovery('foo', autoResolve: false);

      const service = Service(name: 'Some name', type: 'foo');
      await mockReply('onServiceDiscovered',
          {...serializeHandle(capturedHandle), ...serializeService(service)});

      expect(discovery.services.length, 1);
    });

    test('Client is notified if service is lost', () async {
      late String capturedHandle;

      _mockHandlers['startDiscovery'] = (handle, arguments) {
        capturedHandle = handle;
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      final discovery = await _nsd.startDiscovery('foo', autoResolve: false);

      const service = Service(name: 'Some name', type: 'foo');

      await mockReply('onServiceDiscovered',
          {...serializeHandle(capturedHandle), ...serializeService(service)});

      expect(discovery.services.length, 1);

      await mockReply('onServiceLost',
          {...serializeHandle(capturedHandle), ...serializeService(service)});

      expect(discovery.services.length, 0);
    });
  });

  group('$MethodChannelNsdPlatform resolver', () {
    test('Resolver succeeds if native code reports success', () async {
      _mockHandlers['resolve'] = (handle, arguments) {
        // return service info with name only
        mockReply('onResolveSuccessful', {
          ...serializeHandle(handle),
          ...serializeService(const Service(
              name: 'Some name', type: 'foo', host: 'bar', port: 42))
        });
      };

      const service = Service(name: 'Some name', type: 'foo');
      final result = await _nsd.resolve(service);

      // result should contain the original fields plus the updated host / port
      expect(result.name, 'Some name');
      expect(result.type, 'foo');
      expect(result.host, 'bar');
      expect(result.port, 42);
    });

    test('Resolver fails if native code reports failure', () async {
      _mockHandlers['resolve'] = (handle, arguments) {
        // return service info with name only
        mockReply('onResolveFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const service = Service(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.resolve(service), throwsA(matcher));
    });
  });

  group('$MethodChannelNsdPlatform registration', () {
    test('Registration succeeds if native code reports success', () async {
      _mockHandlers['register'] = (handle, arguments) {
        // return service info with name only
        mockReply('onRegistrationSuccessful', {
          ...serializeHandle(handle),
          ...serializeService(const Service(name: 'Some name (2)'))
        });
      };

      final registration =
          await _nsd.register(const Service(name: 'Some name', type: 'foo'));

      final service = registration.service;

      // new service info should contain both the original service type and the updated name
      expect(service.name, 'Some name (2)');
      expect(service.type, 'foo');
    });

    test('Registration fails if native code reports failure', () async {
      // simulate failure callback by native code
      _mockHandlers['register'] = (handle, arguments) {
        mockReply('onRegistrationFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const service = Service(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.register(service), throwsA(matcher));
    });

    test('Unregistration succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (handle, arguments) {
        const service = Service(name: 'Some name (2)', type: 'foo');
        mockReply('onRegistrationSuccessful',
            {...serializeHandle(handle), ...serializeService(service)});
      };

      _mockHandlers['unregister'] = (handle, arguments) {
        mockReply('onUnregistrationSuccessful', {
          ...serializeHandle(handle),
        });
      };

      const service = Service(name: 'Some name', type: 'foo');

      final registration = await _nsd.register(service);
      await _nsd.unregister(registration);
    });

    test('Unregistration fails if native code reports failure', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (handle, arguments) {
        const service = Service(name: 'Some name (2)', type: 'foo');
        mockReply('onRegistrationSuccessful',
            {...serializeHandle(handle), ...serializeService(service)});
      };

      _mockHandlers['unregister'] = (handle, arguments) {
        mockReply('onUnregistrationFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const service = Service(name: 'Some name', type: 'foo');
      final registration = await _nsd.register(service);

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.unregister(registration), throwsA(matcher));
    });
  });

  group('$MethodChannelNsdPlatform native code api', () {
    test('Native code receives error if no handle was given', () async {
      final matcher = isA<PlatformException>().having(
          (e) => e.message, 'error message', contains('Expected handle'));

      expect(mockReply('onDiscoveryStopSuccessful', {}), throwsA(matcher));
    });

    test('Native code receives error if the handle is unknown', () async {
      final matcher = isA<PlatformException>()
          .having((e) => e.message, 'error message', contains('No handler'));

      expect(
          mockReply('onDiscoveryStopSuccessful', serializeHandle('ssafdeaw')),
          throwsA(matcher));
    });
  });

  group('$NsdPlatformInterface', () {
    test('Verify default platform', () async {
      expect(NsdPlatformInterface.instance, isA<MethodChannelNsdPlatform>());
    });

    test('Set custom platform interface', () async {
      final customPlatformInterface = MethodChannelNsdPlatform();
      NsdPlatformInterface.instance = customPlatformInterface;
      expect(NsdPlatformInterface.instance, customPlatformInterface);
    });
  });
}

Future<dynamic> mockReply(String method, dynamic arguments) async {
  const codec = StandardMethodCodec();
  final dataIn = codec.encodeMethodCall(MethodCall(method, arguments));

  final completer = Completer<ByteData?>();
  TestDefaultBinaryMessengerBinding.instance!.channelBuffers
      .push(channelName, dataIn, (dataOut) {
    completer.complete(dataOut);
  });

  final envelope = await completer.future;
  if (envelope != null) {
    return codec.decodeEnvelope(envelope);
  }
}
