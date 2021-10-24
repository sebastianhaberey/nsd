import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

const serviceCount = 9; // 1 discovery + 9 services <= Android limit (10)
const serviceType = '_http._tcp';
const basePort = 56360; // TODO ensure ports are not taken
const uuid = Uuid();
const utf8encoder = Utf8Encoder();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registration, discovery and unregistration of multiple services',
      (WidgetTester _) async {
    final nsd = NsdPlatform.instance;

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final discovery = await nsd.startDiscovery(serviceType);

    // register simultaneously for a bit of stress
    final futures = Iterable<int>.generate(serviceCount)
        .map((e) => createServiceInfo(name, basePort + e))
        .map((e) => nsd.register(e));

    final registrations = await Future.wait(futures);

    // wait for a minimum of ten seconds to ensure there are not more registered services than expected
    await waitForCondition(
        () =>
            findNameStartingWith(discovery.serviceInfos, name).length ==
            serviceCount,
        minWait: const Duration(seconds: 10));

    // unregister simultaneously for a bit of stress
    await Future.wait(registrations.map((e) => nsd.unregister(e)));

    await waitForCondition(
        () => findNameStartingWith(discovery.serviceInfos, name).isEmpty);

    await nsd.stopDiscovery(discovery);
  });

  testWidgets('Verify basic attributes of registered service',
      (WidgetTester _) async {
    final nsd = NsdPlatform.instance;

    final discovery = await nsd.startDiscovery(serviceType);

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final serviceInfo =
        ServiceInfo(name: name, type: serviceType, port: basePort);
    final registration = await nsd.register(serviceInfo);

    await waitForCondition(
        () => findNameStartingWith(discovery.serviceInfos, name).length == 1);

    final receivedServiceInfo =
        findNameStartingWith(discovery.serviceInfos, name).elementAt(0);

    expect(receivedServiceInfo.name, name);
    expect(receivedServiceInfo.type, serviceType);
    expect(receivedServiceInfo.port, basePort);

    await nsd.unregister(registration);
    await nsd.stopDiscovery(discovery);
  });

  testWidgets('Verify txt attribute of registered service',
      (WidgetTester _) async {
    final nsd = NsdPlatform.instance;

    final discovery = await nsd.startDiscovery(serviceType);

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final stringValue = utf8encoder.convert('Löwe');
    final blankValue = Uint8List(0);
    final binaryValue = Uint8List.fromList([0, 1, 2, 3]);

    final txt = <String, Uint8List?>{
      'attribute-a': stringValue,
      'attribute-b': blankValue,
      'attribute-c': null,
      'attribute-d': binaryValue
    };

    final serviceInfo =
        ServiceInfo(name: name, type: serviceType, port: basePort, txt: txt);
    final registration = await nsd.register(serviceInfo);

    await waitForCondition(
        () => findNameStartingWith(discovery.serviceInfos, name).length == 1);

    final receivedServiceInfo =
        findNameStartingWith(discovery.serviceInfos, name).elementAt(0);

    final receivedTxt = receivedServiceInfo.txt!;

    // string values are most common
    expect(receivedTxt['attribute-a'], stringValue);

    // should be present even though it is blank
    expect(receivedTxt.containsKey('attribute-b'), true);

    // not all OS will return a blank list, e.g. macOS / iOS return null here
    expect(isBlankOrNull(receivedTxt['attribute-b']), true);

    // should be present even though it is null
    expect(receivedTxt.containsKey('attribute-c'), true);

    // null values are supported
    expect(receivedTxt['attribute-c'], null);

    // binary data is also supported
    expect(receivedTxt['attribute-d'], binaryValue);

    await nsd.unregister(registration);
    await nsd.stopDiscovery(discovery);
  });
}

isBlankOrNull(Uint8List? value) {
  return value == null || value.isEmpty;
}

ServiceInfo createServiceInfo(String name, int port) {
  return ServiceInfo(name: name + ' $port', type: serviceType, port: port);
}

Iterable<ServiceInfo> findNameStartingWith(
        List<ServiceInfo> serviceInfos, String name) =>
    serviceInfos.where((serviceInfo) => serviceInfo.name!.startsWith(name));

Future<void> waitForCondition(bool Function() condition,
    {Duration minWait = const Duration(),
    Duration maxWait = const Duration(minutes: 1)}) async {
  final start = DateTime.now();
  final min = start.add(minWait);
  final max = start.add(maxWait);

  while (true) {
    final now = DateTime.now();

    if (min.isBefore(now)) {
      if (condition()) {
        return;
      }

      if (now.isAfter(max)) {
        throw TimeoutException('Timeout while waiting for condition', maxWait);
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }
}
