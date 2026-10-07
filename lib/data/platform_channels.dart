import 'package:flutter/services.dart';

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
