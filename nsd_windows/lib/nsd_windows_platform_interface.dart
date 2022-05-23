import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nsd_windows_method_channel.dart';

abstract class NsdWindowsPlatform extends PlatformInterface {
  /// Constructs a NsdWindowsPlatform.
  NsdWindowsPlatform() : super(token: _token);

  static final Object _token = Object();

  static NsdWindowsPlatform _instance = MethodChannelNsdWindows();

  /// The default instance of [NsdWindowsPlatform] to use.
  ///
  /// Defaults to [MethodChannelNsdWindows].
  static NsdWindowsPlatform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NsdWindowsPlatform] when
  /// they register themselves.
  static set instance(NsdWindowsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
