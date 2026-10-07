#!/bin/sh
# プライバシー要件違反のコードパターンを検査する。終了コード: 0=違反なし / 1=違反あり / 2=検査不能
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
ALLOWED=0
ALLOW_RE='//[[:space:]]*privacy-check:[[:space:]]*allow\([^)]+\)[[:space:]]*$'

# check_rule <ラベル> <範囲> <正規表現>...
check_rule() {
  label=$1
  scope=$2
  shift 2
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
  [ -n "$out" ] || return 0
  rc=0
  kept=$(printf '%s\n' "$out" | grep -vE "$ALLOW_RE") || rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "grep が失敗しました($label)" >&2
    exit 2
  fi
  total_n=$(printf '%s\n' "$out" | wc -l)
  if [ -n "$kept" ]; then
    kept_n=$(printf '%s\n' "$kept" | wc -l)
  else
    kept_n=0
  fi
  ALLOWED=$((ALLOWED + total_n - kept_n))
  if [ "$kept_n" -gt 0 ]; then
    echo "[NG] $label"
    printf '%s\n' "$kept"
    TOTAL=$((TOTAL + kept_n))
  fi
}

check_rule 'ログ出力(print / debugPrint / dart:developer)' lib \
  '(^|[^A-Za-z0-9_])print[[:space:]]*\(' 'debugPrint[A-Za-z]*[[:space:]]*\(' 'dart:developer'
check_rule 'ファイル・入出力(dart:io / path_provider)' lib 'dart:io' 'path_provider'
check_rule '共有・クリップボード(Clipboard / share_plus / Share.)' lib \
  'Clipboard' 'share_plus' '(^|[^A-Za-z0-9_])Share\.'
check_rule '通信(http / dio / HttpClient / WebSocket)' lib \
  'package:http/' 'package:dio/' 'HttpClient' 'WebSocket'
check_rule '保存(shared_preferences / sqflite / hive / isar)' lib \
  'package:shared_preferences/' 'package:sqflite/' 'package:hive' 'package:isar'
check_rule 'ロガー(logging / logger)' lib 'package:logging/' 'package:logger/'
check_rule 'lib/domain/ の toString() 実装' lib/domain 'String[[:space:]]+toString[[:space:]]*\('

if [ "$ALLOWED" -gt 0 ]; then
  echo "(privacy-check: allow で除外: $ALLOWED 件)"
fi
if [ "$TOTAL" -gt 0 ]; then
  echo "プライバシー検査: $TOTAL 件の違反"
  exit 1
fi
echo "プライバシー検査: OK"
exit 0
