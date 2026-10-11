#!/usr/bin/env bash
#
# Cài đặt agents-switch (và các alias claude-switch, codex-switch) vào một thư mục
# đã nằm trong $PATH (~/.local/bin, /usr/local/bin, /opt/homebrew/bin).
# Tự động phát hiện hệ điều hành (macOS, Linux, WSL, Windows Git Bash) để cấu hình
# môi trường và file khởi chạy phù hợp. Không ghi alias cứng vào rc file.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$REPO_DIR/agents-switch"
VERSION_SRC="$REPO_DIR/VERSION"
chmod +x "$BIN"

# Symlink tương đối trong repo: không ghim đường dẫn tuyệt đối của máy cài.
ln -sfn agents-switch "$REPO_DIR/claude-switch"
ln -sfn agents-switch "$REPO_DIR/codex-switch"

# 1. Phát hiện hệ điều hành và cấu hình môi trường
OS_NAME="$(uname -s)"
IS_WINDOWS=false

case "$OS_NAME" in
  Darwin)
    PLATFORM="macOS (Keychain credentials)"
    DEFAULT_RC="$HOME/.zshrc"
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="WSL - Linux on Windows (File credentials)"
    else
      PLATFORM="Linux (File credentials)"
    fi
    DEFAULT_RC="$HOME/.bashrc"
    [[ "${SHELL:-}" =~ zsh ]] && DEFAULT_RC="$HOME/.zshrc"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    PLATFORM="Windows - Git Bash / MSYS (File credentials)"
    IS_WINDOWS=true
    DEFAULT_RC="$HOME/.bashrc"
    ;;
  *)
    PLATFORM="$OS_NAME"
    DEFAULT_RC="$HOME/.bashrc"
    ;;
esac

printf '==> Phát hiện hệ điều hành: %s\n' "$PLATFORM"

# 2. Kiểm tra phiên bản Python (yêu cầu >= 3.8)
PYTHON_CMD=""
for cmd in python3 python py; do
  if command -v "$cmd" >/dev/null 2>&1; then
    if "$cmd" -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
      PYTHON_CMD="$cmd"
      break
    fi
  fi
done

if [[ -z "$PYTHON_CMD" ]]; then
  printf '[ERROR] Yêu cầu Python 3.8 trở lên nhưng không tìm thấy trong PATH.\n' >&2
  exit 1
fi
PY_VER="$("$PYTHON_CMD" -c "import sys; print('.'.join(map(str, sys.version_info[:3])))")"
printf '==> Python: %s (%s)\n' "$PYTHON_CMD" "$PY_VER"

# 3. Chọn thư mục đích trong PATH
DEST=""
for d in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  case ":$PATH:" in *":$d:"*) [[ -w "$d" || ! -e "$d" ]] && DEST="$d" && break ;; esac
done

if [[ -z "${DEST:-}" ]]; then
  DEST="$HOME/.local/bin"
  printf '[!] %s chưa nằm trong PATH. Thêm dòng sau vào %s:\n    export PATH="$HOME/.local/bin:$PATH"\n' "$DEST" "$DEFAULT_RC"
fi

mkdir -p "$DEST"
ln -sf "$BIN" "$DEST/agents-switch"
ln -sf "$BIN" "$DEST/claude-switch"
ln -sf "$BIN" "$DEST/codex-switch"

# Windows (Git Bash/MSYS): thêm wrapper .cmd cho CMD/PowerShell. Wrapper chọn client bằng
# cờ -c vì tên file gọi không còn quyết định client như symlink trên Unix.
if [[ "$IS_WINDOWS" == true ]]; then
  [[ -f "$VERSION_SRC" ]] && cp "$VERSION_SRC" "$DEST/VERSION"
  for pair in "agents-switch:" "claude-switch:-c claude" "codex-switch:-c codex"; do
    name="${pair%%:*}"; flag="${pair#*:}"
    cat > "$DEST/$name.cmd" <<CMD
@echo off
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0agents-switch" $flag %*
) else (
    py -3 "%~dp0agents-switch" $flag %*
)
CMD
  done
  printf '[OK] Đã cấu hình wrapper .cmd cho Windows (CMD & PowerShell)\n'
fi

printf '[OK] Đã cài đặt thành công:\n'
printf '     - %s/agents-switch (Hub quản lý đa client AI)\n' "$DEST"
printf '     - %s/claude-switch (Dành riêng cho Claude Code)\n' "$DEST"
printf '     - %s/codex-switch  (Dành riêng cho OpenAI Codex)\n\n' "$DEST"

"$BIN" help
