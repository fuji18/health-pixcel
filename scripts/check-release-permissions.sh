#!/bin/sh
# リリース APK の権限を許可リストと照合する。終了コード: 0=OK / 1=違反あり / 2=検査不能
# 仕様: docs/repository-structure.md「scripts/(アプリの検証スクリプト)」
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=${CHECK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}
cd "$ROOT"

# 許可リスト(改行区切り)。変更するときは先に docs/product-requirements.md「セキュリティ・プライバシー」に理由を書く
ALLOWED_PERMISSIONS='
android.permission.health.READ_STEPS
android.permission.health.READ_SLEEP
io.github.fuji18.healthpixcel.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
'
APK=build/app/outputs/flutter-apk/app-release.apk

# 1. APK の存在
if [ ! -f "$APK" ]; then
  echo "リリース APK がありません: $APK。先にリリースビルドを実行してください(flutter build apk --release)" >&2
  exit 2
fi

# 2. 鮮度
PATHS=""
for p in lib android/app/src android/app/build.gradle.kts android/build.gradle.kts \
  android/settings.gradle.kts android/gradle.properties pubspec.yaml pubspec.lock; do
  [ -e "$p" ] && PATHS="$PATHS $p"
done
if [ -n "$PATHS" ]; then
  # shellcheck disable=SC2086
  NEWER=$(find $PATHS -type f -newer "$APK" | head -n 10)
  if [ -n "$NEWER" ]; then
    echo "リリースビルドが古いため再ビルドしてください。APK より新しいファイル:" >&2
    printf '%s\n' "$NEWER" >&2
    exit 2
  fi
fi

# 3・4. SDK の解決と aapt2 の選択(ディレクトリがあり aapt2 も見つかった最初の候補を使う)
LOCAL_SDK=""
if [ -f android/local.properties ]; then
  LOCAL_SDK=$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -n 1 | tr -d '\r' | sed 's/\\:/:/g; s/\\\\/\\/g')
  if printf '%s' "$LOCAL_SDK" | grep -qE '^[A-Za-z]:' && command -v cygpath >/dev/null 2>&1; then
    LOCAL_SDK=$(cygpath -u "$LOCAL_SDK")
  fi
fi

# find_aapt2 <SDK>: 最新の build-tools のうち aapt2 を持つものを標準出力に出す(無ければ空)
find_aapt2() {
  [ -d "$1/build-tools" ] || return 0
  for d in $(ls -1 "$1/build-tools" | sort -V -r); do
    for name in aapt2 aapt2.exe; do
      if [ -x "$1/build-tools/$d/$name" ] && [ ! -d "$1/build-tools/$d/$name" ]; then
        printf '%s\n' "$1/build-tools/$d/$name"
        return 0
      fi
    done
  done
}

AAPT2=""
REPORT=""
for entry in "ANDROID_HOME|${ANDROID_HOME:-}|(未設定)" "ANDROID_SDK_ROOT|${ANDROID_SDK_ROOT:-}|(未設定)" \
  "android/local.properties の sdk.dir|$LOCAL_SDK|(なし)"; do
  cand_name=${entry%%|*}
  rest=${entry#*|}
  cand_val=${rest%%|*}
  cand_unset=${rest#*|}
  if [ -z "$cand_val" ]; then
    REPORT="$REPORT  $cand_name=$cand_unset
"
  elif [ ! -d "$cand_val" ]; then
    REPORT="$REPORT  $cand_name=$cand_val (ディレクトリなし)
"
  else
    found=$(find_aapt2 "$cand_val")
    if [ -n "$found" ]; then
      AAPT2=$found
      break
    fi
    REPORT="$REPORT  $cand_name=$cand_val (aapt2 なし)
"
  fi
done
if [ -z "$AAPT2" ]; then
  {
    echo "Android SDK または aapt2 が見つかりません。探した場所:"
    printf '%s' "$REPORT"
  } >&2
  exit 2
fi

# 5. 権限一覧の取得(解析対象は stdout のみ。stderr は失敗時の表示用)
ERRF=$(mktemp)
trap 'rm -f "$ERRF"' EXIT
rc=0
RAW=$("$AAPT2" dump permissions "$APK" 2>"$ERRF") || rc=$?
RAW=$(printf '%s\n' "$RAW" | tr -d '\r')
if [ "$rc" -ne 0 ]; then
  echo "aapt2 dump permissions が失敗しました" >&2
  printf '%s\n' "$RAW" >&2
  cat "$ERRF" >&2
  exit 2
fi

# 6. 抽出(権限行から name= を取り出す。取り出せない行があれば検査不能)
PERM_LINES=$(printf '%s\n' "$RAW" | grep -E '^uses-[A-Za-z0-9-]*permission' || true)
if [ -z "$PERM_LINES" ]; then
  echo "権限一覧を取得できませんでした(aapt2 の出力に uses-permission がありません)" >&2
  printf '%s\n' "$RAW" >&2
  exit 2
fi
PERMS=""
BAD=""
while IFS= read -r line; do
  val=$(printf '%s\n' "$line" | sed -n "s/.*[[:space:]]name='\([^']*\)'.*/\1/p; t; s/.*[[:space:]]name=\"\([^\"]*\)\".*/\1/p")
  if [ -z "$val" ]; then
    BAD="$BAD$line
"
  else
    PERMS="$PERMS$val
"
  fi
done <<PERM_EOF
$PERM_LINES
PERM_EOF
if [ -n "$BAD" ]; then
  echo "aapt2 の出力を解釈できない行があります:" >&2
  printf '%s' "$BAD" >&2
  exit 2
fi
PERMS=$(printf '%s' "$PERMS" | sort -u)

# 7. 表示
echo "使用 aapt2: $AAPT2"
echo "APK の権限:"
printf '%s\n' "$PERMS" | sed 's/^/  /'

# 8. 判定
NG=0
if printf '%s\n' "$PERMS" | grep -qxF 'android.permission.INTERNET'; then
  echo "[NG] INTERNET 権限が含まれています(PRD 最重要要件違反: リリース APK は外部と通信できてはならない)"
  NG=$((NG + 1))
fi
for perm in $PERMS; do
  if ! printf '%s\n' "$ALLOWED_PERMISSIONS" | grep -qxF "$perm"; then
    echo "[NG] 許可リストにない権限: $perm"
    NG=$((NG + 1))
  fi
done
if [ "$NG" -gt 0 ]; then
  echo "権限検査: NG(許可リストを変更する場合は先に docs/product-requirements.md「セキュリティ・プライバシー」に理由を追記してください)"
  exit 1
fi
echo "権限検査: OK(INTERNET なし・すべて許可リスト内)"
exit 0
