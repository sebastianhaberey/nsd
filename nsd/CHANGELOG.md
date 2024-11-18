## 4.0.2

* updated flutter version for github action
* removed coverage badge (due to token issue)

## 4.0.1

* issue #60: made change log more readable by putting newest entry first
* updated flutter dependencies

## 4.0.0

* issue #66: prefer using ip address given by android service (thanks RGPaul and jan-mu)
* issue #74: add missing namespace declaration in nsd_android module (thanks Okladnoj)

## 3.0.0

* issue #55: fixed android error where failure on unregistration did not report back to dart side
* issue #50: updated uuid to current version (4.2.1)
* updated dart sdk to >=3.0.0 <4.0.0, flutter to >=3.10.0
* updated various dependencies
* fixed various flutter analyze issues detected by new analyze version

## 2.3.1

* issue #36: added readme section to disable service name validation
* issue #41: removed integration test badges due to unstable CI
* updated example flutter dependencies

## 2.3.0

* issue #29: added an option to disable service type validation by the plugin

## 2.2.3

* issue #22: added error cause "operation not supported"

## 2.2.2

* issue #22: start discovery and register operations now fail properly if windows version is too low

## 2.2.1

* added missing exports for service status, service listener

## 2.2.0

* issue #20: added alternative discovery listening mechanism for found & lost events

## 2.1.0

* windows: migrated current code back to nsd_windows

## 2.0.3

* added nsd_windows_v2 as default dependency for windows

## 2.0.2

* updated github issue template
* new version to update pub.dev after package transfer

## 2.0.1

* fixed contributors section in readme

## 2.0.0

* issue #9: initial release of windows plugin

## 1.5.6

* re-activated auto-resolve in example application
* added projects using nsd section to readme

## 1.5.5

* issue 18: updated android permissions section in readme

## 1.5.4

* issue #18: android: fixed missing plugin exception in release mode
* updated documentation

## 1.5.3

* fixed nsd_android dependency

## 1.5.2

* issue #17: synchronized plugin compile sdk version with current flutter compile sdk version

## 1.5.1

* more unit tests for error handling
* added minimum os requirements to readme
* ci: updated flutter version to 3.0.0

## 1.5.0

* issue #16: added required ios permissions to readme and example app
* android: proper error if wifi multicast permission is missing
* android: updated dependencies (kotlin / gradle)
* platform: more user friendly error handling and output
* updated documentation

## 1.4.4

* add multicast lock required by some android devices

## 1.4.3

* fixed formatting

## 1.4.2

* fixed dart analysis errors

## 1.4.1

* issue #14: harmonized android deserialization method signatures
* updated various dependencies (gradle, android api)

## 1.4.0

* updated to flutter 2.10.0 (also gradle, android api updates)

## 1.3.2

* improved readme structure

## 1.3.1

* issue #11: added faq to documentation

## 1.3.0

* enhancement #7: support for ip addresses

## 1.2.0

* enhancement #8: find all available service types

## 1.1.0

* enhancement #3: proper client feedback if service type is invalid
* fix #1: macos, ios: register() throws internalError if the port is in use
* proper text rendering (toString()) for all classes
* error logging is not enabled per default any more to give the client the choice
* updated example dependencies

## 1.0.5

* more tests

## 1.0.4

* introduced ci for android, macos and ios

## 1.0.3

* added documentation for example app

## 1.0.2

* added documentation as recommended by pub.dev analysis

## 1.0.1

* updated documentation
* verified publisher

## 1.0.0

* initial release