# nsd

[![Flutter CI](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml)

A Flutter plugin for Network Service Discovery (NSD). Supports Android, iOS and macOS.

## Usage

### Service Discovery

```dart
final nsd = NsdPlatform.instance;

final discovery = await nsd.startDiscovery('_http._tcp');
discovery.addListener(() {
  // listener is called each time a service info is added to / removed from discovery.serviceInfos
});

...

await nsd.stopDiscovery(discovery);
```

### Service Registration

```dart
final nsd = NsdPlatform.instance;

const serviceInfo = ServiceInfo(name: 'My Service', type: '_http._tcp', port: 56310);
final registration = await nsd.register(serviceInfo);

...

await nsd.unregister(registration);
```
