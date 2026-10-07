#!/bin/sh
# レイヤー依存(import の向き)を検査する。終了コード: 0=違反なし / 1=違反あり / 2=検査不能
# 仕様: docs/repository-structure.md「scripts/(アプリの検証スクリプト)」
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=${CHECK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}
cd "$ROOT"

if [ ! -d lib ]; then
  echo "lib/ が見つかりません($ROOT)" >&2
  exit 2
fi

TOTAL=0

# check_rule <ラベル> <範囲> <除外の拡張正規表現(空なら除外なし)> <正規表現>...
check_rule() {
  label=$1
  scope=$2
  excl=$3
  shift 3
  [ -d "$scope" ] || return 0
  n_pat=$#
  while [ "$n_pat" -gt 0 ]; do
    set -- "$@" -e "$1"
    shift
    n_pat=$((n_pat - 1))
  done
  rc=0
  out=$(grep -rnE --include='*.dart' "$@" "$scope" 2>/dev/null) || rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "grep が失敗しました($label)" >&2
    exit 2
  fi
  if [ -n "$excl" ] && [ -n "$out" ]; then
    rc=0
    out=$(printf '%s\n' "$out" | grep -vE -e "$excl") || rc=$?
    if [ "$rc" -ge 2 ]; then
      echo "grep が失敗しました($label)" >&2
      exit 2
    fi
  fi
  if [ -n "$out" ]; then
    echo "[NG] $label"
    printf '%s\n' "$out"
    n=$(printf '%s\n' "$out" | wc -l)
    TOTAL=$((TOTAL + n))
  fi
}

check_rule 'package:health/ は lib/data/ 以外で使えません' lib '^lib/data/' 'package:health/'
check_rule 'lib/domain/ は Flutter / Riverpod に依存できません' lib/domain '' 'package:(flutter|flutter_riverpod)/'
check_rule 'lib/application/ は Flutter / Riverpod に依存できません' lib/application '' 'package:(flutter|flutter_riverpod)/'
check_rule 'lib/domain/ は他の層を import できません' lib/domain '' 'package:health_pixcel/(application|data|presentation)/'
check_rule 'lib/application/ は presentation/ を import できません' lib/application '' 'package:health_pixcel/presentation/'
check_rule 'lib/data/ は application/ / presentation/ を import できません' lib/data '' 'package:health_pixcel/(application|presentation)/'
check_rule 'health_connect_repository.dart / platform_channels.dart は lib/data/ と lib/presentation/providers.dart 以外から import できません' lib '^(lib/data/|lib/presentation/providers\.dart:)' "['\"][^'\"]*(health_connect_repository|platform_channels)\\.dart['\"]"
check_rule '相対 import は使えません(package:health_pixcel/ で書いてください)' lib '' \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]\\.\\.?/" \
  "^[[:space:]]*['\"]\\.\\.?/[^'\"]*\\.dart['\"]"

if [ "$TOTAL" -gt 0 ]; then
  echo "レイヤー検査: $TOTAL 件の違反"
  exit 1
fi
echo "レイヤー検査: OK"
exit 0
