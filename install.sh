#!/usr/bin/env bash
#
# Cài claude-switch bằng symlink vào một thư mục đã nằm trong $PATH.
# Không ghi alias vào rc file — repo tham khảo ghi cứng vào ~/.bashrc nên user zsh
# (mặc định của macOS) không bao giờ có lệnh.
#
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/claude-switch"
chmod +x "$SRC"

# Chọn đích đầu tiên đang có trong PATH và ghi được.
for d in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  case ":$PATH:" in *":$d:"*) [[ -w "$d" || ! -e "$d" ]] && DEST="$d" && break ;; esac
done

if [[ -z "${DEST:-}" ]]; then
  DEST="$HOME/.local/bin"
  printf '[!] %s chưa nằm trong PATH. Thêm dòng sau vào ~/.zshrc:\n    export PATH="$HOME/.local/bin:$PATH"\n' "$DEST"
fi

mkdir -p "$DEST"
ln -sf "$SRC" "$DEST/claude-switch"
printf '[OK] Đã cài: %s/claude-switch\n\n' "$DEST"

# In thẳng help thay vì chép lại danh sách lệnh — chép tay thì mỗi lệnh mới lại lệch.
"$SRC" help
