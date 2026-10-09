#!/usr/bin/env bash
#
# Cài đặt agents-switch (và các alias claude-switch, codex-switch) bằng symlink
# vào một thư mục đã nằm trong $PATH (~/.local/bin, /usr/local/bin, /opt/homebrew/bin).
# Không ghi alias cứng vào rc file, đảm bảo tương thích mọi shell (zsh, bash, fish).
#
set -euo pipefail

# Xác định đường dẫn gốc của repository
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$REPO_DIR/agents-switch"
chmod +x "$BIN"

# Đảm bảo symlink claude-switch và codex-switch tồn tại ngay trong repo
ln -sf "$BIN" "$REPO_DIR/claude-switch"
ln -sf "$BIN" "$REPO_DIR/codex-switch"

# Chọn thư mục đầu tiên đang có trong PATH và người dùng có quyền ghi
DEST=""
for d in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  case ":$PATH:" in *":$d:"*) [[ -w "$d" || ! -e "$d" ]] && DEST="$d" && break ;; esac
done

if [[ -z "${DEST:-}" ]]; then
  DEST="$HOME/.local/bin"
  printf '[!] %s chưa nằm trong PATH. Thêm dòng sau vào ~/.zshrc hoặc ~/.bashrc:\n    export PATH="$HOME/.local/bin:$PATH"\n' "$DEST"
fi

mkdir -p "$DEST"

# Tạo symlink cho cả 3 lệnh trong PATH
ln -sf "$BIN" "$DEST/agents-switch"
ln -sf "$BIN" "$DEST/claude-switch"
ln -sf "$BIN" "$DEST/codex-switch"

printf '[OK] Đã cài đặt thành công:\n'
printf '     - %s/agents-switch (Hub quản lý đa client AI)\n' "$DEST"
printf '     - %s/claude-switch (Dành riêng cho Claude Code)\n' "$DEST"
printf '     - %s/codex-switch  (Dành riêng cho OpenAI Codex)\n\n' "$DEST"

# Hiển thị trợ giúp tổng quan
"$BIN" help
