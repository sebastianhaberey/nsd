import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_windows_v2/nsd_windows_v2_method_channel.dart';

void main() {
  MethodChannelNsdWindowsV2 platform = MethodChannelNsdWindowsV2();
  const MethodChannel channel = MethodChannel('nsd_windows_v2');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
