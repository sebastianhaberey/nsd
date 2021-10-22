# TODO

## Current

- android, macos, platform: integration test (& fix) txt resolution
- use proper logging library and let user configure log level for plugin
- macos: unit tests for helper methods
- android: unit tests for helper methods
- platform: replace dynamic arguments / return values with more concrete types where possible  
- read flutter coding guidelines and clean up code
- dart code: cleanup visibility (add _ where needed), order members by dart / flutter style guide
- all: clean up agent id
- ios: copy from macos & test it
- initial release: documentation / changelogs / publish

## Unsorted

- figure out how to deal with logging spam on console
- speed up name allocation by using running discoveries

## Done

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

# Dismissed

- platform: introduce timeouts to prevent stale objects & stale futures
- platform: discriminate errors into client errors and programming errors
- platform: unit tests for DiscoveryAgent / RegistrationAgent
- platform: id to identify service info when discovered / lost / resolved
