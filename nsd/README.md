# nsd

[![Flutter CI](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml)

A Flutter plugin for Network Service Discovery (NSD).

## Service Discovery

```dart
import 'package:nsd/nsd.dart';

final discovery = await startDiscovery('_http._tcp');
discovery.addListener(() {
  // discovery.services contains discovered services
});

// ...

await stopDiscovery(discovery);
```

## Service Registration

```dart
import 'package:nsd/nsd.dart';

final registration = await register(
  const ServiceInfo(name: 'My Service', type: '_http._tcp', port: 56310));

// ...

await unregister(registration);
```
