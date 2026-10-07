import 'package:health_pixcel/domain/models/health_status.dart';
import 'package:health_pixcel/domain/models/sleep_session.dart';

/// ヘルスデータ基盤へのアクセス(データ層の抽象)。
///
/// 上位層はこの型にだけ依存する。プラットフォーム固有の例外は
/// [HealthReadException] に変換して投げる。
abstract interface class HealthRepository {
  /// ヘルスデータ基盤の利用可否。
  Future<HealthAvailability> checkAvailability();

  /// 歩数・睡眠それぞれの権限状態。
  Future<({PermissionStatus steps, PermissionStatus sleep})> checkPermissions();

  /// 歩数・睡眠の READ 権限をまとめてリクエストし、リクエスト後の状態を返す。
  Future<({PermissionStatus steps, PermissionStatus sleep})>
  requestPermissions();

  /// ヘルスコネクトのアプリ権限設定画面を開く(ダイアログが出なくなった場合の逃げ道)。
  /// 開けなかった場合は false を返す。
  Future<bool> openPermissionSettings();

  /// ヘルスコネクトの入手・更新ページ(Play ストア)を開く。開けなかった場合は false を返す。
  Future<bool> openHealthConnectStore();

  /// [start, end) の歩数合計。記録なしは null。失敗時は [HealthReadException] を投げる。
  Future<int?> readTotalSteps(DateTime start, DateTime end);

  /// [start, end) と重なる睡眠セッション(start / end はローカル時刻)。
  /// 失敗時は [HealthReadException] を投げる。
  Future<List<SleepSession>> readSleepSessions(DateTime start, DateTime end);
}

/// ヘルスデータの読み取り失敗。メッセージに健康データの値を含めない。
class HealthReadException implements Exception {
  const HealthReadException(this.kind);

  /// 失敗の種類。
  final HealthErrorKind kind;
}
