
import 'nsd_windows_v2_platform_interface.dart';

class NsdWindowsV2 {
  Future<String?> getPlatformVersion() {
    return NsdWindowsV2Platform.instance.getPlatformVersion();
  }
}
