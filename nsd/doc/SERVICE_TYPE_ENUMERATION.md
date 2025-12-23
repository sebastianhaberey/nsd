# Service Type Enumeration

#### Warning

Even though service type enumeration is an official functionality of DNS-SD, it's not officially
supported on most platforms. It looks like mobile platforms are fading this out (Android),
restricting it deliberately (iOS), or it's simply buggy and not maintained (Windows). In short,
it's probably not a good idea to use it in production.

#### How to

If you want to use it anyways:

1. Start discovery using special service type `_services._dns-sd._udp`
2. Receive list of all service types in network
3. Do discovery for each service type

Start the discovery like this:

```
final discovery = await startDiscovery('_services._dns-sd._udp', autoResolve: false);
```

The `autoResolve` flag is important because the results are not real services and cannot be
resolved. The `discovery.services` list will then be populated with the answers.
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

#### Status

* Stopped working on Android since approximately **Android 13**.
* Requires property list
  key [com.apple.developer.networking.multicast](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast)
  since approximately **iOS 14.5**.
  Users [report success](https://github.com/sebastianhaberey/nsd/issues/67) after requesting
  permission from Apple for this entitlement.
* On **Windows**, detects types of services registered by other machines correctly, but
  does not detect types of services that were registered on the local machine.