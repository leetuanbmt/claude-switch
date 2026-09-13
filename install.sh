#!/usr/bin/env bash
#
# Cài đặt claude-switch vào thư mục trong $PATH.
# Tự động phát hiện hệ điều hành (macOS, Linux, WSL, Windows Git Bash)
# để cấu hình môi trường và file khởi chạy phù hợp.
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/claude-switch"
VERSION_SRC="$(cd "$(dirname "$0")" && pwd)/VERSION"
chmod +x "$SRC"

# 1. Phát hiện hệ điều hành và cấu hình môi trường
OS_NAME="$(uname -s)"
IS_WINDOWS=false
IS_WSL=false

case "$OS_NAME" in
  Darwin)
    PLATFORM="macOS (Keychain credentials)"
    DEFAULT_RC="$HOME/.zshrc"
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="WSL - Linux on Windows (File credentials)"
      IS_WSL=true
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
ln -sf "$SRC" "$DEST/claude-switch"

# Nếu chạy trên Windows qua Git Bash/MSYS, tạo thêm wrapper .cmd và copy VERSION để CMD/PowerShell dùng được
if [[ "$IS_WINDOWS" == true ]]; then
  cat <<'EOF' > "$DEST/claude-switch.cmd"
@echo off
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0claude-switch" %*
) else (
    py -3 "%~dp0claude-switch" %*
)
EOF
  if [[ -f "$VERSION_SRC" ]]; then
    cp "$VERSION_SRC" "$DEST/VERSION"
  fi
  printf '[OK] Đã cấu hình wrapper claude-switch.cmd cho Windows (CMD & PowerShell)\n'
fi

printf '[OK] Đã cài đặt: %s/claude-switch\n\n' "$DEST"

# In thông tin trợ giúp
"$SRC" help
