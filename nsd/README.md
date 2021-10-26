# nsd

[![Flutter CI](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/flutter-ci.yml)

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

![Screenshot](https://github.com/sebastianhaberey/nsd/blob/main/documentation/images/screenshot.png)

The plugin includes an example application that can be used to start multiple discoveries 
and register multiple services. It will discover its own services but also other services of type
`_http._tcp` in the local network, such as the printer in the screenshot above. 

- Use the action button to add a discovery or register a new service.
- Swipe the cards left or right to dismiss a discovery or service.
- The application log will show the calls and callbacks platform side vs. native side.
- The [example application source code](example/lib/main.dart) demonstrates how to use the 
  discovery object as a [ChangeNotifier](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple).