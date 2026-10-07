import 'package:flutter/services.dart';
import 'package:health_pixcel/domain/models/health_status.dart';

/// 起動理由の取得(MethodChannel `health_pixcel/launch`)。
class LaunchChannel {
  /// [channel] はテスト用。省略時は `health_pixcel/launch`。
  const LaunchChannel({
    MethodChannel channel = const MethodChannel('health_pixcel/launch'),
  }) : _channel = channel; // ignore: prefer_initializing_formals

  final MethodChannel _channel;

  /// 起動理由。未知の値・失敗時は [LaunchAction.normal]。
  Future<LaunchAction> getLaunchAction() async {
    try {
      final value = await _channel.invokeMethod<String>('getLaunchAction');
      return switch (value) {
        'permissionRationale' => LaunchAction.permissionRationale,
        _ => LaunchAction.normal,
      };
    } catch (_) {
      return LaunchAction.normal;
    }
  }
}

/// ヘルスコネクトの設定画面を開く(MethodChannel `health_pixcel/health_connect_settings`)。
class HealthConnectSettingsChannel {
  /// [channel] はテスト用。省略時は `health_pixcel/health_connect_settings`。
  const HealthConnectSettingsChannel({
    MethodChannel channel = const MethodChannel(
      'health_pixcel/health_connect_settings',
    ),
  }) : _channel = channel; // ignore: prefer_initializing_formals

  final MethodChannel _channel;

  /// 開けたら true。開けなかった・失敗時は false。
  Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } catch (_) {
      return false;
    }
  }
}
