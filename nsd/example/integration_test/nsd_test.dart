import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

const serviceCount = 9; // 1 discovery + 9 services <= Android limit (10)
const serviceType = '_http._tcp';
const basePort = 56360; // TODO ensure ports are not taken
const uuid = Uuid();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registration, discovery and unregistration of multiple services',
      (WidgetTester _) async {
    final platform = NsdPlatform.instance;

    final name = uuid.v4(); // UUID as service name base ensures test isolation

    final discovery = await platform.startDiscovery(serviceType);

    // register simultaneously for a bit of stress
    final futures = Iterable<int>.generate(serviceCount)
        .map((e) => createServiceInfo(name, basePort + e))
        .map((e) => platform.register(e));

    final registrations = await Future.wait(futures);

    // wait for a minimum of ten seconds to ensure there are not more registered services than expected
    await waitForCondition(
        () =>
            findNameStartingWith(discovery.serviceInfos, name).length ==
            serviceCount,
        minWait: const Duration(seconds: 10));

    // unregister simultaneously for a bit of stress
    await Future.wait(registrations.map((e) => platform.unregister(e)));

    await waitForCondition(
        () => findNameStartingWith(discovery.serviceInfos, name).isEmpty);

    await platform.stopDiscovery(discovery);
  });
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
