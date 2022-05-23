import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_windows_v2/nsd_windows_v2.dart';
import 'package:nsd_windows_v2/nsd_windows_v2_platform_interface.dart';
import 'package:nsd_windows_v2/nsd_windows_v2_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNsdWindowsV2Platform 
    with MockPlatformInterfaceMixin
    implements NsdWindowsV2Platform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NsdWindowsV2Platform initialPlatform = NsdWindowsV2Platform.instance;

  test('$MethodChannelNsdWindowsV2 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNsdWindowsV2>());
  });

  test('getPlatformVersion', () async {
    NsdWindowsV2 nsdWindowsV2Plugin = NsdWindowsV2();
    MockNsdWindowsV2Platform fakePlatform = MockNsdWindowsV2Platform();
    NsdWindowsV2Platform.instance = fakePlatform;
  
    expect(await nsdWindowsV2Plugin.getPlatformVersion(), '42');
  });
}
