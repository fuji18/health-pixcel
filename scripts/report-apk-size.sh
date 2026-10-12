#!/bin/sh
# リリース APK のサイズと内訳を Markdown で出す。終了コード: 0=目安以内 / 1=目安超過 / 2=検査不能
# 仕様: docs/repository-structure.md「scripts/(アプリの検証スクリプト)」
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=${CHECK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}
cd "$ROOT"

# 目安(arm64-v8a 相当、MB)。変えるときは docs/architecture.md「パフォーマンス要件」も合わせて直す
BUDGET_MB=25
APK=build/app/outputs/flutter-apk/app-release.apk

# 1. APK の存在
if [ ! -f "$APK" ]; then
  echo "リリース APK がありません: $APK。先にリリースビルドを実行してください(flutter build apk --release)" >&2
  exit 2
fi

# 2. unzip の存在
if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip が見つかりません" >&2
  exit 2
fi

# 3. 全体サイズ
TOTAL=$(wc -c <"$APK" | tr -d ' ') || { echo "APK のサイズを取得できません: $APK" >&2; exit 2; }

# 4・5. エントリ一覧を区分ごとに集計(出力: "種別<TAB>キー<TAB>表示名<TAB>バイト")
ENTRIES=$(unzip -v "$APK") || { echo "unzip -v に失敗しました: $APK" >&2; exit 2; }
SUMMARY=$(printf '%s\n' "$ENTRIES" | awk '
  NF >= 8 && $1 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
    name = $8
    for (i = 9; i <= NF; i++) name = name " " $i
    size = $3
    if (name ~ /^lib\/[^\/]+\//) {
      rest = substr(name, 5)
      abi = substr(rest, 1, index(rest, "/") - 1)
      file = substr(rest, index(rest, "/") + 1)
      if (file == "libapp.so") kind = 1
      else if (file == "libflutter.so") kind = 2
      else kind = 3
      native[abi, kind] += size
      abis[abi] = 1
    } else if (name ~ /^assets\/flutter_assets\//) assets += size
    else if (name ~ /^classes[^\/]*\.dex$/) dex += size
    else if (name ~ /^res\// || name == "resources.arsc") res += size
    else other += size
  }
  END {
    for (a in abis) {
      for (k = 1; k <= 3; k++) {
        if (native[a, k] > 0) {
          label = (k == 1) ? "Dart AOT" : (k == 2) ? "Flutter エンジン" : "その他ネイティブ"
          printf "N\t%s\t%s(%s)\t%d\n", a, label, a, native[a, k]
        }
      }
    }
    printf "A\t-\tFlutter アセット\t%d\n", assets
    printf "A\t-\tDEX\t%d\n", dex
    printf "A\t-\tリソース\t%d\n", res
    printf "A\t-\tその他\t%d\n", other
  }
') || { echo "エントリの集計に失敗しました: $APK" >&2; exit 2; }

# 6. arm64-v8a の存在
if ! printf '%s\n' "$SUMMARY" | awk -F'\t' '$1 == "N" && $2 == "arm64-v8a" { f = 1 } END { exit f ? 0 : 1 }'; then
  echo "arm64-v8a のネイティブライブラリがありません" >&2
  exit 2
fi

# 7. arm64-v8a 相当
OTHER_ABI=$(printf '%s\n' "$SUMMARY" | awk -F'\t' '$1 == "N" && $2 != "arm64-v8a" { s += $4 } END { printf "%d", s }') || { echo "ABI 別サイズの集計に失敗しました: $APK" >&2; exit 2; }
ARM=$((TOTAL - OTHER_ABI))

# 8. 出力
mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
ARM_MB=$(mb "$ARM")
echo "### リリース APK サイズ"
echo
echo "| 項目 | MB | バイト |"
echo "|---|---:|---:|"
echo "| APK 全体(fat) | $(mb "$TOTAL") | $TOTAL |"
echo "| **arm64-v8a 相当**(目安 $BUDGET_MB MB 以下) | **$ARM_MB** | $ARM |"
echo
echo "内訳(圧縮後サイズ):"
echo
echo "| 区分 | MB | バイト |"
echo "|---|---:|---:|"
{
  printf '%s\n' "$SUMMARY" | awk -F'\t' '$1 == "N"' | sort -t "$(printf '\t')" -k2,2 -s
  printf '%s\n' "$SUMMARY" | awk -F'\t' '$1 == "A"'
} | while IFS="$(printf '\t')" read -r _ _ label bytes; do
  echo "| $label | $(mb "$bytes") | $bytes |"
done

# 9. 目安との比較
if awk -v b="$ARM" -v m="$BUDGET_MB" 'BEGIN { exit (b / 1048576 > m) ? 0 : 1 }'; then
  echo "arm64-v8a 相当サイズ $ARM_MB MB が目安 $BUDGET_MB MB を超えています(docs/architecture.md「パフォーマンス要件」)" >&2
  exit 1
fi
exit 0
