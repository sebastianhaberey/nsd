# nsd

[![Platform Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/platform-tests.yml)
[![Android Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/android-tests.yml)
[![iOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/ios-tests.yml)
[![macOS Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/macos-tests.yml)
[![Windows Tests](https://github.com/sebastianhaberey/nsd/actions/workflows/windows-tests.yml/badge.svg)](https://github.com/sebastianhaberey/nsd/actions/workflows/windows-tests.yml)
[![codecov](https://codecov.io/gh/sebastianhaberey/nsd/branch/main/graph/badge.svg?token=JPGRAMJWV2)](https://codecov.io/gh/sebastianhaberey/nsd)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![pub package](https://img.shields.io/pub/v/nsd.svg)](https://pub.dev/packages/nsd)

A Flutter plugin for network service discovery and registration (aka NSD / DNS-SD / Bonjour / mDNS).

<br></br>

## Basic Usage

### Service Discovery

```dart
import 'package:nsd/nsd.dart';

final discovery = await startDiscovery('_http._tcp');
discovery.addListener(() {
  // discovery.services contains discovered services
});

// ...

await stopDiscovery(discovery);
```

or alternatively:

```dart
discovery.addServiceListener((service, status) {
  if (status == ServiceStatus.found) {
    // put service in own collection, etc.
  }
});
```

### Service Registration

```dart
import 'package:nsd/nsd.dart';

final registration = await register(
  const Service(name: 'Foo', type: '_http._tcp', port: 56000));

// ...

await unregister(registration);
```
<br></br>

## Permissions

### Android

Add the following permissions to your manifest:

```Xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

### iOS

Add the following permissions to your Info.plist (replace service type with your own):

```Xml
<key>NSLocalNetworkUsageDescription</key>
<string>Required to discover local network devices</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```
<br></br>

## Example application

<img src="https://raw.githubusercontent.com/sebastianhaberey/nsd/main/documentation/images/screenshot.png" width=100%>

The plugin includes an example application that can be used to start multiple discoveries 
and register multiple services. It will discover its own services but also other services of type
`_http._tcp` in the local network, such as the printer in the screenshot above. 

- Use the action button to add a discovery or register a new service.
- Swipe the cards left or right to dismiss a discovery or service.
- The application log will show the calls and callbacks platform side vs. native side.
- The source code demonstrates how to use the discovery object as a 
  [ChangeNotifier](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple).

<br></br>

## Minimum OS Requirements

- Android: API level 21 (Android 5.0)
- iOS: 12.0
- macOS: 10.11 (El Capitan)
- Windows 10 (19H1/1903) (Mai 2019 Update)

<br></br>

## Advanced Usage

### Get IP Addresses for Service

First, do you really _need_ the IP address? If you just want to connect to the service, 
the host name that is supplied with the service should do just fine. In fact, connecting by 
host name is recommended on the [Apple Developer Forums](https://developer.apple.com/forums/thread/673771?answerId=662293022#662293022).

If you _do_ need the IP address, you can configure automatic ip lookup for your discovery
like this:

```dart
final discovery = await startDiscovery(serviceType, ipLookupType: IpLookupType.any);
```

Each discovered service will now have a list of IP addresses attached to it.

### Discover All Services of All Types on Local Network

The current way to do this would be:

1. Start discovery using special service type `_services._dns-sd._udp` 
2. Receive list of all service types in network 
3. Do discovery for each service type

Start the discovery like this:

```dart
final discovery = await startDiscovery('_services._dns-sd._udp', autoResolve: false);
```

The `autoResolve` flag is important because the results are not real services and cannot be resolved. The `discovery.services` list will then be populated with the answers. 
The `Service` instances returned will contain service type info, like so:

```
{service.type: _tcp.local, service.name: _foo, ...}
{service.type: _tcp.local, service.name: _bar, ...}
```

The first component of the service type (e.g. `_foo`) is contained in the service name attribute, 
the second component of the service type (e.g. `_tcp`) is contained in the service type attribute.

Even though using a service structure to represent a service type feels like a hack, it seems to be 
consistent on Android / macOS / iOS platform APIs. Since they are all doing it, 
the plugin has the same behavior.

**Note**: this currently doesn't function 100% on Windows platforms. While it will detect the types of
services registered by other machines correctly, it will not detect types of services that were 
registered using the plugin.

### Disable service name validation

Service names are validated by the plugin according to [RFC 6335](https://datatracker.ietf.org/doc/html/rfc6335#section-5.1):

* MUST be at least 1 character and no more than 15 characters long
* MUST contain only US-ASCII [ANSI.X3.4-1986] letters 'A' - 'Z' and 'a' - 'z', digits '0' - '9', and hyphens ('-', ASCII 0x2D or decimal 45)
* MUST contain at least one letter ('A' - 'Z' or 'a' - 'z')
* MUST NOT begin or end with a hyphen
* hyphens MUST NOT be adjacent to other hyphens

If you are getting the error message _"Service type must be in format..."_ but you still want to work
with service names that do not conform to the rules, you can disable service name validation entirely:

```dart
disableServiceTypeValidation(true);
```

Be aware that some network environments might not support non-conformant service names.

### Enable Debug Logging

In order to help debugging, logging can be enabled for individual topics. For example

```dart
enableLogging(LogTopic.errors);
enableLogging(LogTopic.calls);
```

will log errors and all calls to the native side (and their callbacks), which often yields useful information.

<br></br>

## Contributors

[lxp-git](https://github.com/lxp-git) - wrote the Windows prototype!

<br></br>

## Projects using nsd

🎮 [Tic Tac Toe Local Multiplayer Game for Android](https://github.com/lakscastro/ttt) by Laks Castro

<br></br>
