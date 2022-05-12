
import 'nsd_windows_platform_interface.dart';

class NsdWindows {
  Future<String?> getPlatformVersion() {
    return NsdWindowsPlatform.instance.getPlatformVersion();
  }
}
