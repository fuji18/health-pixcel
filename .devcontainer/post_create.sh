#!/bin/bash
set -e

echo "=== Post-create setup ==="

# Install Playwright deps (only when the project actually uses Playwright)
echo "[1/6] Installing Playwright dependencies..."
if grep -qE '"(@playwright/test|playwright)"' package.json 2>/dev/null; then
  npx --yes playwright install-deps chromium
else
  echo "  Playwright not found in package.json. Skipping (E2E 導入時に再実行される)."
fi

# Install Claude Code
echo "[2/6] Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Install Codex CLI (Codex 併用ハーネスの前提。docs/template-dev/codex-harness.html §12.4)
# 認証(codex login)はリビルドのたびに人間の手動操作が要る。~/.codex は
# コンテナ内にしか無いため、ここで入れられるのは CLI 本体だけ。
#
# 本体パッケージはランチャー(bin/codex.js)だけを含み、実体はプラットフォーム別の
# optionalDependencies(エイリアス指定)で降ってくる。optional なので取得に失敗しても
# npm install は成功扱いで終わり、実行時に初めて
#   Error: Missing optional dependency @openai/codex-linux-x64
# で落ちる。インストール成否は npm ではなく codex --version で判定する。
echo "[3/6] Installing Codex CLI..."
npm install -g @openai/codex || true
if ! codex --version &>/dev/null; then
  echo "  ⚠️  プラットフォーム別バイナリの取得に失敗。再試行します..."
  npm install -g @openai/codex@latest || true
fi
if codex --version &>/dev/null; then
  if codex login status &>/dev/null; then
    echo "  Already authenticated with Codex."
  else
    echo "  ⚠️  Not authenticated. Run 'codex login'(通らなければ 'codex login --device-auth')."
    echo "      '--with-api-key' は使わないこと(ChatGPT Plus 枠ではなく API 従量課金になる)。"
  fi
else
  echo "  ⚠️  Codex CLI のインストールに失敗しました。手動で 'npm install -g @openai/codex@latest' を実行してください。"
fi

# GitHub authentication
# Codespaces が注入する GITHUB_TOKEN を尊重し、ローカル devcontainer では
# LOCAL_GH_TOKEN(ホストの GH_TOKEN)をフォールバックとして使う
echo "[4/6] Setting up GitHub authentication..."
GITHUB_TOKEN="${GITHUB_TOKEN:-${LOCAL_GH_TOKEN:-}}"
if gh auth status &>/dev/null; then
  echo "  Already authenticated with GitHub."
elif [ -n "$GITHUB_TOKEN" ]; then
  echo "$GITHUB_TOKEN" | gh auth login --with-token
  gh auth setup-git
  echo "  GitHub authentication complete (via GITHUB_TOKEN)."
else
  echo "  ⚠️  Not authenticated. Run 'gh auth login' to authenticate manually."
fi

# git の作成者(コミットに必要)。VS Code の「ホストの .gitconfig をコピー」はホスト側に
# user.* が無いと何も入らない(#28)。メールアドレスをリポジトリにコミットしないため、
# GitHub アカウントから noreply 形式を組み立てる。--global ではなく --local にするのは、
# VS Code がアタッチ時に ~/.gitconfig を書き込むため順序に依存しないようにするため
# (.git/config はワークスペース側にあり、リビルドしても残る)。
echo "[5/6] Setting up git author..."
if [ -n "$(git config user.email || true)" ]; then
  echo "  Already configured: $(git config user.name) <$(git config user.email)>"
elif GH_USER="$(gh api user --jq '"\(.login) \(.id)"' 2>/dev/null)" && [ -n "$GH_USER" ]; then
  read -r GH_LOGIN GH_ID <<< "$GH_USER"
  [ -n "$(git config user.name || true)" ] || git config --local user.name "$GH_LOGIN"
  git config --local user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
  echo "  Configured: $(git config user.name) <${GH_ID}+${GH_LOGIN}@users.noreply.github.com>(.git/config)"
else
  echo "  ⚠️  git の作成者を設定できませんでした(gh 未認証)。手動で設定してください:"
  echo "      git config --local user.name <name> && git config --local user.email <email>"
fi

# Install Flutter SDK(analyze / format / test 用。実機実行とリリースビルドは Windows 側で行う)
# バージョンは docs/architecture.md「言語・ランタイム」と CI(ci.yml)に揃える。
# Android SDK は入れないため、flutter doctor の Android toolchain 警告は想定どおり。
FLUTTER_VERSION="3.47.6"
FLUTTER_HOME="$HOME/flutter"
echo "[6/6] Installing Flutter SDK ${FLUTTER_VERSION}..."
if [ -x "$FLUTTER_HOME/bin/flutter" ] && "$FLUTTER_HOME/bin/flutter" --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION} "; then
  echo "  Flutter ${FLUTTER_VERSION} already installed."
else
  rm -rf "$FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
"$FLUTTER_HOME/bin/flutter" config --no-analytics --no-cli-animations >/dev/null
"$FLUTTER_HOME/bin/dart" --disable-analytics >/dev/null 2>&1 || true
"$FLUTTER_HOME/bin/flutter" --version
# devcontainer.json の remoteEnv.PATH は /home/vscode/flutter/bin を直書きしている
# (${containerEnv:HOME} はイメージの ENV に HOME が無く空になるため使えない。#28)。
# remoteUser を変えると PATH と FLUTTER_HOME が食い違うので、ここで気づけるようにする。
if [ "$(command -v flutter || true)" != "$FLUTTER_HOME/bin/flutter" ]; then
  echo "  ⚠️  PATH 上の flutter が $FLUTTER_HOME/bin/flutter ではありません。devcontainer.json の remoteEnv.PATH を確認してください。"
fi
if [ -f pubspec.yaml ]; then
  "$FLUTTER_HOME/bin/flutter" pub get
fi

echo "=== Setup complete ==="
