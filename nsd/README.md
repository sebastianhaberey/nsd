# nsd

[![Platform Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml)
[![Android Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml)
[![iOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml)
[![macOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml)
[![codecov](https://codecov.io/gh/sebastianhaberey/nsd/branch/main/graph/badge.svg?token=JPGRAMJWV2)](https://codecov.io/gh/sebastianhaberey/nsd)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for network service discovery and registration (aka NSD / DNS-SD / Bonjour / mDNS).

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
  const Service(name: 'Foo', type: '_http._tcp', port: 56000));

// ...

await unregister(registration);
```

## Example App

<img src="https://raw.githubusercontent.com/sebastianhaberey/nsd/main/documentation/images/screenshot.png" width=100%>

The plugin includes an example application that can be used to start multiple discoveries 
and register multiple services. It will discover its own services but also other services of type
`_http._tcp` in the local network, such as the printer in the screenshot above. 

- Use the action button to add a discovery or register a new service.
- Swipe the cards left or right to dismiss a discovery or service.
- The application log will show the calls and callbacks platform side vs. native side.
- The source code demonstrates how to use the discovery object as a 
  [ChangeNotifier](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple).
  
## FAQ

### How to get the IP address for a discovered service?

First, do you really _need_ the IP address? If you just want to connect to the service, 
the host name that is supplied with the service should do just fine. In fact, connecting by 
host name is recommended on the [Apple Developer Forums](https://developer.apple.com/forums/thread/673771?answerId=662293022#662293022).

If you _do_ need the IP address, you can configure your discovery like this:

```dart
final discovery = await startDiscovery(serviceType, ipLookupType: IpLookupType.any);
```

Each discovered service will now have a list of IP addresses attached to it.

### How to find all services on the local network, regardless of type

The current way to do this is would be:

1. Start discovery using special service type `_services._dns-sd._udp` 
2. Receive list of all service types in network 
3. Do discovery for each service type

Start the discovery like this:

```Dart
final discovery = await startDiscovery('_services._dns-sd._udp', autoResolve: false);
```

The `autoResolve` flag is important because the results are not real services and cannot be resolved. The `discovery.services` list will then be populated with the answers. 
The answers look like this:

```
{service.type: _tcp.local, service.host: null, service.name: _foo, handle: a353ff28-40dd-425d-a5a0-9966eea0c708}
{service.type: _tcp.local, service.host: null, service.name: _bar, handle: a353ff28-40dd-425d-a5a0-9966eea0c708}
```

The first component of the service type (e.g. `_foo`) is contained in the service name attribute, 
the second component of the service type (e.g. `_tcp`) is contained in the service type attribute.

Even though using a service structure to represent a service type feels like a hack, it seems to be 
consistent on Android / macOS / iOS platform APIs. Since they are both doing it, 
the plugin has the same behavior.

### How to enable logging for diagnostic purposes

In order to help debugging, logging can be enabled for individual topics. For example

```Dart
enableLogging(LogTopic.calls);
```

will log all calls to the native side (and their callbacks), which often contain useful 
information.
