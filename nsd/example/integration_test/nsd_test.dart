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

    await waitForCondition(
        discovery,
        (serviceInfos) =>
            findNameStartingWith(serviceInfos, name).length == serviceCount);

    // unregister simultaneously for a bit of stress
    await Future.wait(registrations.map((e) => platform.unregister(e)));

    await waitForCondition(discovery,
        (serviceInfos) => findNameStartingWith(serviceInfos, name).isEmpty);

    await platform.stopDiscovery(discovery);
  });
}

ServiceInfo createServiceInfo(String name, int port) {
  return ServiceInfo(name: name + ' $port', type: serviceType, port: port);
}

Iterable<ServiceInfo> findNameStartingWith(
        List<ServiceInfo> serviceInfos, String name) =>
    serviceInfos.where((serviceInfo) => serviceInfo.name!.startsWith(name));

Future<void> waitForCondition(Discovery discovery,
    bool Function(List<ServiceInfo> serviceInfos) condition) async {
  final completer = Completer<void>();

  listener() {
    if (condition(discovery.items)) {
      completer.complete();
    }
  }

  discovery.addListener(listener);
  return completer.future
      .whenComplete(() => discovery.removeListener(listener));
}
