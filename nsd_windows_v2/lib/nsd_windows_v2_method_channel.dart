import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nsd_windows_v2_platform_interface.dart';

/// An implementation of [NsdWindowsV2Platform] that uses method channels.
class MethodChannelNsdWindowsV2 extends NsdWindowsV2Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nsd_windows_v2');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
