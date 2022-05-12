import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_windows/nsd_windows.dart';
import 'package:nsd_windows/nsd_windows_platform_interface.dart';
import 'package:nsd_windows/nsd_windows_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNsdWindowsPlatform 
    with MockPlatformInterfaceMixin
    implements NsdWindowsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NsdWindowsPlatform initialPlatform = NsdWindowsPlatform.instance;

  test('$MethodChannelNsdWindows is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNsdWindows>());
  });

  test('getPlatformVersion', () async {
    NsdWindows nsdWindowsPlugin = NsdWindows();
    MockNsdWindowsPlatform fakePlatform = MockNsdWindowsPlatform();
    NsdWindowsPlatform.instance = fakePlatform;
  
    expect(await nsdWindowsPlugin.getPlatformVersion(), '42');
  });
}
