import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_pixcel/data/platform_channels.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launch = MethodChannel('health_pixcel/launch');
  const settings = MethodChannel('health_pixcel/health_connect_settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(
    MethodChannel channel,
    Future<Object?> Function(MethodCall call)? handler,
  ) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  group('LaunchChannel', () {
    test('permissionRationale を返し、getLaunchAction を呼ぶ', () async {
      final methods = <String>[];
      mock(launch, (call) async {
        methods.add(call.method);
        return 'permissionRationale';
      });
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.permissionRationale,
      );
      expect(methods, ['getLaunchAction']);
    });

    test('normal は normal', () async {
      mock(launch, (call) async => 'normal');
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.normal,
      );
    });

    test('未知の値は normal', () async {
      mock(launch, (call) async => 'other');
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.normal,
      );
    });

    test('null は normal', () async {
      mock(launch, (call) async => null);
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.normal,
      );
    });

    test('PlatformException は normal', () async {
      mock(launch, (call) async => throw PlatformException(code: 'x'));
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.normal,
      );
    });

    test('ハンドラ未設定(MissingPluginException)は normal', () async {
      expect(
        await const LaunchChannel().getLaunchAction(),
        LaunchAction.normal,
      );
    });
  });

  group('HealthConnectSettingsChannel', () {
    test('true を返し、open を呼ぶ', () async {
      final methods = <String>[];
      mock(settings, (call) async {
        methods.add(call.method);
        return true;
      });
      expect(await const HealthConnectSettingsChannel().open(), isTrue);
      expect(methods, ['open']);
    });

    test('false は false', () async {
      mock(settings, (call) async => false);
      expect(await const HealthConnectSettingsChannel().open(), isFalse);
    });

    test('null は false', () async {
      mock(settings, (call) async => null);
      expect(await const HealthConnectSettingsChannel().open(), isFalse);
    });

    test('PlatformException は false', () async {
      mock(settings, (call) async => throw PlatformException(code: 'x'));
      expect(await const HealthConnectSettingsChannel().open(), isFalse);
    });

    test('ハンドラ未設定は false', () async {
      expect(await const HealthConnectSettingsChannel().open(), isFalse);
    });
  });
}
