import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_platform_interface/src/method_channel_nsd_platform.dart';
import 'package:nsd_platform_interface/src/nsd_platform_interface.dart';
import 'package:nsd_platform_interface/src/serialization.dart';

const channelName = 'com.haberey/nsd';
const utf8encoder = Utf8Encoder();

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
      return _mockHandlers[methodCall.method]
          ?.call(handle, methodCall.arguments);
    });
  });

  group('$MethodChannelNsdPlatform discovery', () {
    test('Start succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      await _nsd.startDiscovery('_foo._tcp');
    });

    test('Start succeeds for special service enumeration type', () async {
      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      await _nsd.startDiscovery('_services._dns-sd._udp');
    });

    test('Autoresolve', () async {
      late String capturedHandle;

      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        capturedHandle = handle;
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      // set up mock resolver to answer with "resolved" service
      _mockHandlers['resolve'] = (handle, arguments) {
        mockReply('onResolveSuccessful', {
          ...serializeHandle(handle),
          ...serializeService(const Service(
              name: 'Some name', type: 'bar', host: 'baz', port: 56000))
        });
      };

      final discovery = await _nsd.startDiscovery('_foo._tcp');

      // simulate unresolved discovered service
      await mockReply('onServiceDiscovered', {
        ...serializeHandle(capturedHandle),
        ...serializeService(const Service(name: 'Some name', type: '_foo._tcp'))
      });

      final discoveredService = discovery.services.elementAt(0);
      expect(discoveredService.host, 'baz');
      expect(discoveredService.port, 56000);
    });

    test('IP lookup', () async {
      late String capturedHandle;

      // simulate success callback by native code
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        capturedHandle = handle;
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      // set up mock resolver to answer with "resolved" service
      _mockHandlers['resolve'] = (handle, arguments) {
        mockReply('onResolveSuccessful', {
          ...serializeHandle(handle),
          ...serializeService(const Service(
              name: 'Some name', type: 'bar', host: 'localhost', port: 56000))
        });
      };

      final discovery = await _nsd.startDiscovery('_foo._tcp',
          ipLookupType: IpLookupType.any);

      // simulate unresolved discovered service
      await mockReply('onServiceDiscovered', {
        ...serializeHandle(capturedHandle),
        ...serializeService(const Service(name: 'Some name', type: '_foo._tcp'))
      });

      final discoveredService = discovery.services.elementAt(0);
      expect(discoveredService.addresses, isNotEmpty);
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

      expect(_nsd.startDiscovery('_foo._tcp'), throwsA(matcher));
    });

    test('Start fails if service type is invalid', () async {
      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.illegalArgument)
          .having((e) => e.message, 'error message', contains('format'));

      expect(_nsd.startDiscovery('foo'), throwsA(matcher));
    });

    test('Start fails if IP lookup is enabled without auto resolve', () async {
      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.illegalArgument)
          .having((e) => e.message, 'error message',
              contains('Auto resolve must be enabled'));

      expect(
          _nsd.startDiscovery('_foo._tcp',
              autoResolve: false, ipLookupType: IpLookupType.v4),
          throwsA(matcher));
    });

    test('Stop succeeds if native code reports success', () async {
      _mockHandlers['startDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStartSuccessful', serializeHandle(handle));
      };

      _mockHandlers['stopDiscovery'] = (handle, arguments) {
        mockReply('onDiscoveryStopSuccessful', serializeHandle(handle));
      };

      final discovery = await _nsd.startDiscovery('_foo._tcp');
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

      final discovery = await _nsd.startDiscovery('_foo._tcp');

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

      final discovery =
          await _nsd.startDiscovery('_foo._tcp', autoResolve: false);

      const service = Service(name: 'Some name', type: '_foo._tcp');
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

      final discovery =
          await _nsd.startDiscovery('_foo._tcp', autoResolve: false);

      const service = Service(name: 'Some name', type: '_foo._tcp');

      await mockReply('onServiceDiscovered',
          {...serializeHandle(capturedHandle), ...serializeService(service)});

      expect(discovery.services.length, 1);

      await mockReply('onServiceLost',
          {...serializeHandle(capturedHandle), ...serializeService(service)});

      expect(discovery.services.length, 0);
    });
  });

  group('$MethodChannelNsdPlatform resolve', () {
    test('Resolve succeeds if native code reports success', () async {
      _mockHandlers['resolve'] = (handle, arguments) {
        // return service info with name only
        mockReply('onResolveSuccessful', {
          ...serializeHandle(handle),
          ...serializeService(Service(
              name: 'Some name',
              type: '_foo._tcp',
              host: 'bar',
              port: 42,
              txt: {'string': utf8encoder.convert('κόσμε')}))
        });
      };

      const service = Service(name: 'Some name', type: '_foo._tcp');
      final result = await _nsd.resolve(service);

      // result should contain the original fields plus the updated host / port
      expect(result.name, 'Some name');
      expect(result.type, '_foo._tcp');
      expect(result.host, 'bar');
      expect(result.port, 42);
      expect(result.txt, {'string': utf8encoder.convert('κόσμε')});
    });

    test('Resolve fails if native code reports failure', () async {
      _mockHandlers['resolve'] = (handle, arguments) {
        // return service info with name only
        mockReply('onResolveFailed', {
          ...serializeHandle(handle),
          ...serializeErrorCause(ErrorCause.maxLimit),
          ...serializeErrorMessage('some error')
        });
      };

      const service = Service(name: 'Some name', type: '_foo._tcp');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.resolve(service), throwsA(matcher));
    });

    test('Resolve fails if service type is invalid', () async {
      const service = Service(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.illegalArgument)
          .having((e) => e.message, 'error message', contains('format'));

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

      final registration = await _nsd
          .register(const Service(name: 'Some name', type: '_foo._tcp'));

      final service = registration.service;

      // new service info should contain both the original service type and the updated name
      expect(service.name, 'Some name (2)');
      expect(service.type, '_foo._tcp');
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

      const service = Service(name: 'Some name', type: '_foo._tcp');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.maxLimit)
          .having((e) => e.message, 'error message', contains('some error'));

      expect(_nsd.register(service), throwsA(matcher));
    });

    test('Registration fails if service type is invalid', () async {
      const service = Service(name: 'Some name', type: 'foo');

      final matcher = isA<NsdError>()
          .having((e) => e.cause, 'error cause', ErrorCause.illegalArgument)
          .having((e) => e.message, 'error message', contains('format'));

      expect(_nsd.register(service), throwsA(matcher));
    });

    test('Unregistration succeeds if native code reports success', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (handle, arguments) {
        const service = Service(name: 'Some name (2)', type: '_foo._tcp');
        mockReply('onRegistrationSuccessful',
            {...serializeHandle(handle), ...serializeService(service)});
      };

      _mockHandlers['unregister'] = (handle, arguments) {
        mockReply('onUnregistrationSuccessful', {
          ...serializeHandle(handle),
        });
      };

      const service = Service(name: 'Some name', type: '_foo._tcp');

      final registration = await _nsd.register(service);
      await _nsd.unregister(registration);
    });

    test('Unregistration fails if native code reports failure', () async {
      // simulate success callback by native code
      _mockHandlers['register'] = (handle, arguments) {
        const service = Service(name: 'Some name (2)', type: '_foo._tcp');
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

      const service = Service(name: 'Some name', type: '_foo._tcp');
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

  group('$Service', () {
    test('Verify default platform', () async {
      const service = Service(
          name: 'Some name (2)', type: '_foo._tcp', host: 'localhost', port: 0);
      expect(
          service.toString(),
          stringContainsInOrder(
              ['Some name (2)', '_foo._tcp', 'localhost', '0']));
    });

    test('Attributes are contained in text rendering', () async {
      final service = Service(
          name: 'Some name',
          type: '_foo._tcp',
          host: 'bar',
          port: 42,
          txt: {'string': utf8encoder.convert('κόσμε')});

      expect(service.toString(), contains('Some name'));
      expect(service.toString(), contains('_foo._tcp'));
      expect(service.toString(), contains('bar'));
      expect(service.toString(), contains(42.toString()));
      expect(service.toString(),
          contains(utf8encoder.convert('κόσμε').toString()));
    });
  });

  group('$Discovery', () {
    test('Attributes are contained in text rendering', () async {
      const service = Service(name: 'Some name', type: '_foo._tcp');
      final discovery = Discovery('bar');
      discovery.add(service);

      expect(discovery.toString(), contains('bar'));
      expect(discovery.toString(), contains('Some name'));
      expect(discovery.toString(), contains('_foo._tcp'));
    });
  });

  group('$Registration', () {
    test('Attributes are contained in text rendering', () async {
      const service = Service(name: 'Some name', type: '_foo._tcp');
      final registration = Registration('bar', service);

      expect(registration.toString(), contains('bar'));
      expect(registration.toString(), contains('Some name'));
      expect(registration.toString(), contains('_foo._tcp'));
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
