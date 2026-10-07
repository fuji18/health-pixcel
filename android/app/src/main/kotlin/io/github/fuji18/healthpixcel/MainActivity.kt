package io.github.fuji18.healthpixcel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.health.connect.HealthConnectManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** health パッケージの権限リクエストを受けるため FlutterFragmentActivity を継承する。 */
class MainActivity : FlutterFragmentActivity() {
    /**
     * 利用目的のインテントで起動されたら利用目的画面のルートを返す。
     * Dart に届くのは新しいエンジンを作るとき(この Activity インスタンスの生成時)だけ。onNewIntent は扱わない。
     */
    override fun getInitialRoute(): String? =
        when (intent?.action) {
            ACTION_SHOW_PERMISSIONS_RATIONALE,
            Intent.ACTION_VIEW_PERMISSION_USAGE -> ROUTE_PERMISSION_RATIONALE
            else -> super.getInitialRoute()
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> result.success(openHealthConnectSettings())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * このアプリの権限画面 → ヘルスコネクトのホームの順に開く。どちらも開けなければ false。
     * パッケージ可視性の制限で 事前の解決可否の確認は当てにならないため、startActivity の例外で判定する。
     */
    private fun openHealthConnectSettings(): Boolean =
        tryStartActivity(
            Intent(HealthConnectManager.ACTION_MANAGE_HEALTH_PERMISSIONS)
                .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName),
        ) || tryStartActivity(Intent(ACTION_HEALTH_HOME_SETTINGS))

    /** 開けたら true。ActivityNotFoundException / SecurityException は false。 */
    private fun tryStartActivity(intent: Intent): Boolean =
        try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }

    private companion object {
        const val SETTINGS_CHANNEL = "health_pixcel/health_connect_settings"
        const val ACTION_SHOW_PERMISSIONS_RATIONALE =
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
        const val ACTION_HEALTH_HOME_SETTINGS = "android.health.connect.action.HEALTH_HOME_SETTINGS"
        const val ROUTE_PERMISSION_RATIONALE = "/permission-rationale"
    }
}
