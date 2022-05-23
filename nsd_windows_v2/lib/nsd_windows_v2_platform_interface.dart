import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nsd_windows_v2_method_channel.dart';

abstract class NsdWindowsV2Platform extends PlatformInterface {
  /// Constructs a NsdWindowsV2Platform.
  NsdWindowsV2Platform() : super(token: _token);

  static final Object _token = Object();

  static NsdWindowsV2Platform _instance = MethodChannelNsdWindowsV2();

  /// The default instance of [NsdWindowsV2Platform] to use.
  ///
  /// Defaults to [MethodChannelNsdWindowsV2].
  static NsdWindowsV2Platform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NsdWindowsV2Platform] when
  /// they register themselves.
  static set instance(NsdWindowsV2Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
