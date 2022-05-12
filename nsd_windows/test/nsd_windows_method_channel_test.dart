import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd_windows/nsd_windows_method_channel.dart';

void main() {
  MethodChannelNsdWindows platform = MethodChannelNsdWindows();
  const MethodChannel channel = MethodChannel('nsd_windows');

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
