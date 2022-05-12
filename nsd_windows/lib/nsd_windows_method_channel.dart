import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nsd_windows_platform_interface.dart';

/// An implementation of [NsdWindowsPlatform] that uses method channels.
class MethodChannelNsdWindows extends NsdWindowsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nsd_windows');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
