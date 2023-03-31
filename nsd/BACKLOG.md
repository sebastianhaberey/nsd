# Backlog

## Current

## Unsorted

- linux platform

## Done

- add documentation for disabling service type validation
- windows platform
- platform: add toString() for discovery and registration
- platform: onUnregistrationSuccessful: discard handlers
- android: serialization: serializeServiceInfo: use serializeKey instead of string constants
- ci: set up the "big" integration test for macos / ios / android using github actions
- initial release: documentation / changelogs / clean up pubspec files / publish
- use proper logging library and let user configure log level for plugin
- all: clean up agent id
- all: test (& fix) txt resolution
- ios: copy from macos & test it
- platform: tests for resolve method
- platform: platform-agnostic integration tests (live functionality)
- macos: resolve functionality
- android: resolve functionality
- platform, android, macos: clean up serialize keys
- platform: test and improve error handling
- platform: migrate tests to new api (TestDefaultBinaryMessengerBinding)
- android: register
- android: use handler id everywhere
- macos: register
- platform: extend example application to support multiple discoveries and multiple registrations

## Trashcan

- add documentation for disabling service type validation
- platform: add enableLogTopics -> would be api change ("enableLogging" + "enableLoggings"?)
- platform: replace dynamic arguments / return values with more concrete types where possible
- clean up code according to flutter coding guidelines -> done for most aspects
- dart code: cleanup visibility (add _ where needed) -> not sure about readability
- android: unit tests for helper methods -> not much code and covered by integration tests
- macos: unit tests for helper methods -> not much code and covered by integration tests
- speed up name allocation by using running discoveries -> wait until needed
- figure out how to deal with logging spam on console -> ok now
- platform: introduce timeouts to prevent stale objects & stale futures -> wait until needed
- platform: discriminate errors into client errors and programming errors -> wait until neeeded
- platform: unit tests for DiscoveryAgent / RegistrationAgent -> not needed with new api
- platform: id to identify service info when discovered / lost / resolved -> not needed with new api
