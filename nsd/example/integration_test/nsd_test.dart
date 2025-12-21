import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nsd/nsd.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

const serviceCount = 10; // 1 discovery + 9 services <= Android limit (10)
const serviceType = '_http._tcp';
const basePort = 56360; // TODO ensure ports are not taken
const uuid = Uuid();
const utf8encoder = Utf8Encoder();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registration, discovery and unregistration of multiple services',
      (WidgetTester _) async {
    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final discovery = await startDiscovery(serviceType);

    // register simultaneously for a bit of stress
    final futures = Iterable<int>.generate(serviceCount)
        .map((e) => createService(name, basePort + e))
        .map((e) => register(e));

    final registrations = await Future.wait(futures);

    await waitForCondition(() =>
        findNameStartingWith(discovery.services, name).length == serviceCount);

    // unregister simultaneously for a bit of stress
    await Future.wait(registrations.map((e) => unregister(e)));

    await waitForCondition(
        () => findNameStartingWith(discovery.services, name).isEmpty);

    await stopDiscovery(discovery);
  });

  testWidgets('Verify basic attributes of registered service',
      (WidgetTester _) async {
    final discovery = await startDiscovery(serviceType);

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final service = Service(name: name, type: serviceType, port: basePort);
    final registration = await register(service);

    final receivedService = await waitForValue(
        () => firstOrNull(findNameStartingWith(discovery.services, name)));

    expect(receivedService.name, name);
    expect(receivedService.type, serviceType);
    expect(receivedService.port, basePort);

    await unregister(registration);
    await stopDiscovery(discovery);
  });

  testWidgets('Verify txt attribute of registered service',
      (WidgetTester _) async {
    final discovery = await startDiscovery(serviceType);

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final stringValue = utf8encoder.convert('κόσμε');
    final blankValue = Uint8List(0);

    final txt = <String, Uint8List?>{
      'a-string': stringValue,
      'a-blank': blankValue,
      'a-null': null,
    };

    // these bytes cannot appear in a correct UTF-8 string,
    // see https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
    final binaryValue = Uint8List.fromList([254, 255]);

    // Android doesn't support binary txt data due to signature of NsdServiceInfo.setAttribute() and
    // Windows doesn't support binary txt data due to signature of DnsServiceConstructInstance()
    if (!Platform.isAndroid && !Platform.isWindows) {
      txt['a-binary'] = binaryValue;
    }

    final service =
        Service(name: name, type: serviceType, port: basePort, txt: txt);
    final registration = await register(service);

    final Service receivedService = await waitForValue(
        () => firstOrNull(findNameStartingWith(discovery.services, name)));

    final receivedTxt = receivedService.txt!;

    // string values are most common
    expect(receivedTxt['a-string'], stringValue);

    // should be present even though it is blank
    expect(receivedTxt.containsKey('a-blank'), true);

    // should theoretically be an emtpy list but Android / macOS / iOS / Windows return null here
    // update 12/2025: apparently Android 15 returns empty list now
    expect(isNullOrEmpty(receivedTxt['a-blank']), true);

    // should be present even though it is null
    expect(receivedTxt.containsKey('a-null'), true);

    // null values are supported
    expect(receivedTxt['a-null'], null);

    if (!Platform.isAndroid && !Platform.isWindows) {
      expect(receivedTxt['a-binary'], binaryValue);
    }

    await unregister(registration);
    await stopDiscovery(discovery);
  });

  testWidgets('Registration is possible if port is in use',
      (WidgetTester _) async {
    final server = await startServer(); // start server on port
    final service =
        Service(name: uuid.v4(), type: serviceType, port: server.port);
    final registration = await register(service);

    await unregister(registration);
    await server.close();
  });

  testWidgets('Find all available service types', skip: !Platform.isMacOS,
      (WidgetTester _) async {
    final discovery =
        await startDiscovery('_services._dns-sd._udp', autoResolve: false);

    final serviceA =
        Service(name: uuid.v4(), type: '_foo._tcp', port: basePort + 0);
    final registrationA = await register(serviceA);

    final serviceB =
        Service(name: uuid.v4(), type: '_bar._tcp', port: basePort + 1);
    final registrationB = await register(serviceB);

    await waitForCondition(() =>
        findNameStartingWith(discovery.services, '_foo').length == 1 &&
        findNameStartingWith(discovery.services, '_bar').length == 1);

    await stopDiscovery(discovery);

    await unregister(registrationB);
    await unregister(registrationA);
  });

  testWidgets('Look up IP addresses for service', (WidgetTester _) async {
    final discovery = await startDiscovery(serviceType,
        autoResolve: true, ipLookupType: IpLookupType.any);

    final name = uuid.v4();

    final registration =
        await register(Service(name: name, type: serviceType, port: basePort));

    final Service discoveredService = await waitForValue(
        () => firstOrNull(findNameStartingWith(discovery.services, name)));

    expect(discoveredService.addresses, isNotEmpty);

    await stopDiscovery(discovery);
    await unregister(registration);
  });
}

isNullOrEmpty(Uint8List? value) => value == null || value.isEmpty;

Service createService(String name, int port) =>
    Service(name: '$name $port', type: serviceType, port: port);

Iterable<Service> findNameStartingWith(List<Service> services, String name) {
  return services.where((service) => service.name!.startsWith(name));
}

Future<void> waitForCondition(bool Function() condition,
    {Duration minWait = const Duration(),
    Duration maxWait = const Duration(minutes: 1)}) async {
  await waitForValue(() => condition() ? true : null,
      minWait: minWait, maxWait: maxWait);
}

Future<T> waitForValue<T>(T? Function() valueFunc,
    {Duration minWait = const Duration(),
    Duration maxWait = const Duration(minutes: 1)}) async {
  final start = DateTime.now();
  final min = start.add(minWait);
  final max = start.add(maxWait);

  while (true) {
    final now = DateTime.now();

    if (min.isBefore(now)) {
      final value = valueFunc();
      if (value != null) {
        return value;
      }

      if (now.isAfter(max)) {
        throw TimeoutException('Timeout while waiting for value', maxWait);
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }
}

Future<HttpServer> startServer() async {
  final handler = const Pipeline()
      .addHandler((request) => Response.ok('Request for "${request.url}"'));
  return shelf_io
      .serve(handler, InternetAddress.anyIPv4, 0)
      .then((server) => server);
}

T? firstOrNull<T>(Iterable<T> iterable) {
  return iterable.length == 1 ? iterable.first : null;
}
