import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:nsd_platform_interface/src/method_channel_nsd_platform.dart';
import 'package:nsd_platform_interface/src/serialization.dart';

const channelName = 'com.haberey/nsd';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelNsdPlatform _platform;
  late MethodChannel _methodChannel;
  late Map<String, Function(String agentId, dynamic arguments)> _mockHandlers;

  setUp(() async {
    _platform = MethodChannelNsdPlatform();
    _methodChannel = const MethodChannel(channelName);
    _mockHandlers = HashMap();

    // install custom handler that routes method calls to mock handlers
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel,
            (MethodCall methodCall) async {
      final agentId = deserializeAgentId(methodCall.arguments)!;
      _mockHandlers[methodCall.method]?.call(agentId, methodCall.arguments);
    });
  });

  group('$MethodChannelNsdPlatform discovery', () {
    test('Start succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeAgentId(agentId));
      };

      await _platform.startDiscovery('foo');
    });

    test('Start fails if native code reports failure', () async {
      // simulate failure callback by native code
      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStartFailed', {
          ...serializeAgentId(agentId),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_platform.startDiscovery('foo'), throwsA(matcher));
    });

    test('Stop succeeds if native code reports success', () async {
      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeAgentId(agentId));
      };

      _mockHandlers['stopDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStopSuccessful', serializeAgentId(agentId));
      };

      final discovery = await _platform.startDiscovery('foo');
      await _platform.stopDiscovery(discovery);
    });

    test('Stop fails if native code reports failure', () async {
      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeAgentId(agentId));
      };

      _mockHandlers['stopDiscovery'] = (agentId, arguments) {
        mockReply('onDiscoveryStopFailed', {
          ...serializeAgentId(agentId),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      final discovery = await _platform.startDiscovery('foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_platform.stopDiscovery(discovery), throwsA(matcher));
    });

    test('Client is notified if service is discovered', () async {
      late String capturedAgentId;

      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        capturedAgentId = agentId;
        mockReply('onDiscoveryStartSuccessful', serializeAgentId(agentId));
      };

      final discovery =
          await _platform.startDiscovery('foo', autoResolve: false);

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');
      await mockReply('onServiceDiscovered', {
        ...serializeAgentId(capturedAgentId),
        ...serializeServiceInfo(serviceInfo)
      });

      expect(discovery.items.length, 1);
    });

    test('Client is notified if service is lost', () async {
      late String capturedAgentId;

      _mockHandlers['startDiscovery'] = (agentId, arguments) {
        capturedAgentId = agentId;
        mockReply('onDiscoveryStartSuccessful', serializeAgentId(agentId));
      };

      final discovery =
          await _platform.startDiscovery('foo', autoResolve: false);

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');

      await mockReply('onServiceDiscovered', {
        ...serializeAgentId(capturedAgentId),
        ...serializeServiceInfo(serviceInfo)
      });

      expect(discovery.items.length, 1);

      await mockReply('onServiceLost', {
        ...serializeAgentId(capturedAgentId),
        ...serializeServiceInfo(serviceInfo)
      });

      expect(discovery.items.length, 0);
    });
  });

  group('$MethodChannelNsdPlatform resolver', () {
    test('Resolver succeeds if native code reports success', () async {
      _mockHandlers['resolve'] = (agentId, arguments) {
        // return service info with name only
        mockReply('onResolveSuccessful', {
          ...serializeAgentId(agentId),
          ...serializeServiceInfo(const ServiceInfo(
              name: 'Some name', type: 'foo', host: 'bar', port: 42))
        });
      };

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');
      final result = await _platform.resolve(serviceInfo);

      // result should contain the original fields plus the updated host / port
      expect(result.name, 'Some name');
      expect(result.type, 'foo');
      expect(result.host, 'bar');
      expect(result.port, 42);
    });

    test('Resolver fails if native code reports failure', () async {
      _mockHandlers['resolve'] = (agentId, arguments) {
        // return service info with name only
        mockReply('onResolveFailed', {
          ...serializeAgentId(agentId),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_platform.resolve(serviceInfo), throwsA(matcher));
    });
  });

  group('$MethodChannelNsdPlatform registration', () {
    test('Registration succeeds if native code reports success', () async {
      _mockHandlers['register'] = (agentId, arguments) {
        // return service info with name only
        mockReply('onRegistrationSuccessful', {
          ...serializeAgentId(agentId),
          ...serializeServiceInfo(const ServiceInfo(name: 'Some name (2)'))
        });
      };

      final registration = await _platform
          .register(const ServiceInfo(name: 'Some name', type: 'foo'));

      final serviceInfo = registration.serviceInfo;

      // new service info should contain both the original service type and the updated name
      expect(serviceInfo.name, 'Some name (2)');
      expect(serviceInfo.type, 'foo');
    });

    test('Registration fails if native code reports failure', () async {
      // simulate failure callback by native code
      _mockHandlers['register'] = (agentId, arguments) {
        mockReply('onRegistrationFailed', {
          ...serializeAgentId(agentId),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_platform.register(serviceInfo), throwsA(matcher));
    });

    test('Unregistration succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (agentId, arguments) {
        const serviceInfo = ServiceInfo(name: 'Some name (2)', type: 'foo');
        mockReply('onRegistrationSuccessful', {
          ...serializeAgentId(agentId),
          ...serializeServiceInfo(serviceInfo)
        });
      };

      _mockHandlers['unregister'] = (agentId, arguments) {
        mockReply('onUnregistrationSuccessful', {
          ...serializeAgentId(agentId),
        });
      };

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');

      final registration = await _platform.register(serviceInfo);
      await _platform.unregister(registration);
    });

    test('Unregistration fails if native code reports failure', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (agentId, arguments) {
        const serviceInfo = ServiceInfo(name: 'Some name (2)', type: 'foo');
        mockReply('onRegistrationSuccessful', {
          ...serializeAgentId(agentId),
          ...serializeServiceInfo(serviceInfo)
        });
      };

      _mockHandlers['unregister'] = (agentId, arguments) {
        mockReply('onUnregistrationFailed', {
          ...serializeAgentId(agentId),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const serviceInfo = ServiceInfo(name: 'Some name', type: 'foo');
      final registration = await _platform.register(serviceInfo);

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_platform.unregister(registration), throwsA(matcher));
    });
  });

  group('$MethodChannelNsdPlatform native code api', () {
    test('Native code receives error if no handler found', () async {
      final matcher = isA<PlatformException>()
          .having((e) => e.message, 'error message', contains('No handler'));

      expect(mockReply('onDiscoveryStopSuccessful', serializeAgentId('bar')),
          throwsA(matcher));
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
