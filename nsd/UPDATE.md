# Update Project

## Upgrade Flutter

```
flutter doctor -v # optional, to see current version
flutter upgrade
```

## Upgrade dependencies

```
cd nsd_platform_interface
flutter pub outdated
flutter pub upgrade
```

Direct dependencies and dev dependencies should be up-to-date now. There will likely be some
transitive dependencies that cannot be upgraded due to dependency constraints, which is fine.

## Update Android

### Get version information from current Flutter template

Generate fresh project using current (stable) Flutter:

```
flutter create flutter_version_probe
cd flutter_version_probe
cat android/gradle/wrapper/gradle-wrapper.properties | grep distributionUrl # Gradle wrapper version
cat android/settings.gradle.kts | grep com.android.application # AGP version
cat android/settings.gradle.kts | grep kotlin # Kotlin version
cat android/app/build.gradle.kts | grep sourceCompatibility # Java source compatiblity
cat android/app/build.gradle.kts | grep targetCompatibility # Java target compatiblity

```

### Update Gradle wrapper

```
cd nsd/example/android
./gradlew wrapper --gradle-version 8.14 --distribution-type all
```

Copy the resulting changes
from [example gradle-wrapper.properties](example/android/gradle/wrapper/gradle-wrapper.properties)
to
[nsd_android gradle-wrapper.properties](../nsd_android/android/gradle/wrapper/gradle-wrapper.properties).

### Update AGP and Kotlin version

Update the values in [example settings.gradle](example/android/settings.gradle).

### Update Java / Kotlin compatibility

Update the values in [example build.gradle](example/android/app/build.gradle)
and [nsd_android build.gradle](../nsd_android/android/build.gradle)

## iOS / macOS

### Get version information from current Flutter template

```
grep -n "DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj # show iOS deployment target
grep -n "DEPLOYMENT_TARGET" macos/Runner.xcodeproj/project.pbxproj # show macOS deployment target
```

### Regenerate files

- Open example/ios in Xcode -> Runner target -> Build Settings -> iOS Deployment Target -> set to
  new target.
- Open example/macos in Xcode -> Runner target -> Build Settings -> macOS Deployment Target -> set
  to new target.

```
cd example
flutter clean
flutter pub get
```

- Run iOS example
- Run macOS example