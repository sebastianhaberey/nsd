# nsd

[![Platform Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml)
[![Android Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml)
[![iOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml)
[![macOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/sebastianhaberey/nsd/branch/main/graph/badge.svg?token=JPGRAMJWV2)](https://codecov.io/gh/sebastianhaberey/nsd)

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