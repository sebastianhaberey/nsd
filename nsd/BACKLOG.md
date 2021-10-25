# TODO

## Current

- macos: unit tests for helper methods
- android: unit tests for helper methods
- initial release: documentation / changelogs / clean up pubspec files / publish

## Unsorted

- platform: replace dynamic arguments / return values with more concrete types where possible
- clean up code according to flutter coding guidelines
- dart code: cleanup visibility (add _ where needed)

## Dustbin

- speed up name allocation by using running discoveries
- figure out how to deal with logging spam on console
- platform: introduce timeouts to prevent stale objects & stale futures
- platform: discriminate errors into client errors and programming errors
- platform: unit tests for DiscoveryAgent / RegistrationAgent
- platform: id to identify service info when discovered / lost / resolved

## Done

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
