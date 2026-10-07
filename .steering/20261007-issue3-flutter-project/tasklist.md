# タスクリスト: Flutter プロジェクト生成と Android 構成(#3)

- [x] `flutter create` で生成し、README.md / .gitignore / analysis_options.yaml を処置する(design §1・§5)
- [x] Android パッケージを `io.github.fuji18.healthpixcel` に揃え、minSdk を 34 にする(design §2・§3)
- [x] main / release の AndroidManifest.xml と MainActivity.kt を書く(design §4)
- [x] 依存を追加し、`pub deps` の一覧を取る(design §6.1)
- [x] main.dart / app.dart / app_test.dart を置き換える(design §6.2〜6.4)
- [x] 検証コマンドを通す(design §7)

## 申し送り

- 実装は fork 1 往復で完了。検収は code-reviewer 1 巡(must-fix 0 / should-fix 1 / nit 3)、test-runner 全パス
- `flutter pub get` 系を実行するたびに Flutter 3.47 が `analysis_options.yaml` へ `analyzer: exclude` を自動で追記する。戻しても再発するため受け入れ、design.md と `development-guidelines.md` に反映した
- ルートに `.gitignore` が既にあると、`flutter create` は生成版を作らない。統合する項目は Flutter テンプレートの既知の項目(`*.iml` / `migrate_working_dir/` / `app.*.symbols` / `app.*.map.json`)で補った
- 依存の審査: direct は health / flutter_riverpod / intl。transitive にもネットワーク通信・解析 SDK は無い(`listen` は Flutter 公式の純 Dart 実装)
- 残り(後続チケットで扱う): リリース APK の実際の権限(`health` プラグインがマニフェストに足すもの)は #4・#10 で確定する。release の署名が debug 鍵のままなのは生成物の既定どおり。`pubspec.yaml` に残った Cupertino Icons の生成コメントは今回は残した(nit)
