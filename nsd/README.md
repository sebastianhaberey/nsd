# nsd

[![Flutter CI](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml)

A Flutter plugin for Network Service Discovery (NSD). Supports Android, iOS and macOS.

## Usage

### Service Discovery

```dart
final nsd = NsdPlatform.instance;

final discovery = await nsd.startDiscovery('_http._tcp');
discovery.addListener(() {
  // listener is called each time a service is added to / removed from discovery.services
});

...

await nsd.stopDiscovery(discovery);
```

### Service Registration

```dart
final nsd = NsdPlatform.instance;

final registration = await nsd.register(ServiceInfo(name: 'My Service', type: '_http._tcp'));

...

await nsd.unregister(registration);
```
