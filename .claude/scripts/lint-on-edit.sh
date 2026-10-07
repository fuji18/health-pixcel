#!/bin/bash
# PostToolUse(Edit|Write) async hook: Dart ファイルの編集後に静的解析を走らせる。
#
# health-pixcel(Flutter)向けに書き換えたもの(.steering/20261006-flutter-stack-migration)。
# テンプレート版(TS: eslint + tsc)の設計(.steering/20260829-issue44-lint-on-edit-scope)を踏襲する:
#   1. 解析は編集した 1 ファイルだけに掛ける。全体解析は編集と無関係な既存の指摘を
#      毎編集ごとにコンテキストへ載せ、ファイル数に比例して太る
#      (dart analyze はファイル単位でも型を含めて解析するため、tsc のような全体検査は要らない)
#   2. 多重起動は flock で待ち合わせる(プロセスが死ねばカーネルが解放する)
# ⚠️ .claude/scripts/ はテンプレート所有(owned)。/sync-template で上書きされたら、この版を当て直す。
set -uo pipefail

f="$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)"
[ -n "$f" ] || exit 0
case "$f" in
  *.dart) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Flutter プロジェクト生成前(pubspec.yaml なし)はパッケージ解決ができず誤検知だらけになる
[ -f pubspec.yaml ] || exit 0

LOCK=".claude/.lint-on-edit.lock"
LOCK_WAIT=100   # settings.json の hook timeout(120s)の内側に収める
DART="$(command -v dart 2>/dev/null || true)"
[ -n "$DART" ] || DART="$HOME/flutter/bin/dart"

root="$(realpath . 2>/dev/null || printf '%s' "$PWD")"

# 編集ファイル 1 本を検査する。プロジェクト外・削除済みのパスは黙って捨てる。
run_checks() {
  local target="$1" abs="" rel=""

  # シンボリックリンク経由で $PWD と字面が食い違うと無検査になるため正規化する
  abs="$(realpath "$target" 2>/dev/null || printf '%s' "$target")"
  case "$abs" in
    "$root"/*) rel="${abs#"$root"/}" ;;
    /*) return 0 ;;
    *) rel="$abs" ;;
  esac
  [ -f "$rel" ] || return 0
  [ -x "$DART" ] || return 0

  # 指摘が無いときの定型行(No issues found!)は出さない
  "$DART" analyze "$rel" 2>&1 | grep -v -e '^Analyzing ' -e '^No issues found' | tail -20
}

# 先行プロセスの完了を待ってから検査する(スキップしない = 連続編集でも取りこぼさない)。
# 待ちきれなければこの回は諦める。hook の timeout に食い込ませて SIGKILL されるより行儀がよく、
# 検査は常にその時点の内容を読むので、後続の編集で検査される。
if command -v flock >/dev/null 2>&1; then
  if { exec 9>"$LOCK"; } 2>/dev/null; then
    flock -w "$LOCK_WAIT" 9 || exit 0
  fi
fi

run_checks "$f"
exit 0
