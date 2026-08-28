#!/usr/bin/env bash
#
# Self-check cho claude-switch. Chạy trong $HOME giả nên KHÔNG đụng tới tài khoản thật:
# script derive mọi đường dẫn từ $HOME, và tự chọn credential backend dạng file khi
# ~/.claude/.credentials.json tồn tại → Keychain thật không bao giờ bị ghi.
#
set -euo pipefail
CS="$(cd "$(dirname "$0")" && pwd)/claude-switch"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Dựng một "tài khoản đang đăng nhập" giả: config + credential backend file.
login_as() {  # $1=uuid $2=email
  mkdir -p "$HOME/.claude"
  printf '{"refreshToken":"tok-%s"}' "$1" > "$HOME/.claude/.credentials.json"
  python3 -c '
import json, sys
json.dump({
  "oauthAccount": {"accountUuid": sys.argv[1], "emailAddress": sys.argv[2],
                   "organizationUuid": "org-" + sys.argv[1],
                   "organizationName": "Org " + sys.argv[1]},
  "userID": "user-" + sys.argv[1],
  "cachedUsageUtilization": {"utilization": {
      "five_hour": {"utilization": 7, "resets_at": "2026-08-11T00:00:00+00:00"},
      "seven_day": {"utilization": 42, "resets_at": "2026-08-15T00:00:00+00:00"}}},
  "mcpServers": {"keep-me": {}},          # key thuộc về máy — phải sống sót qua switch
  "projects": {"/some/path": {"allowedTools": []}},
}, open(sys.argv[3], "w"))' "$1" "$2" "$HOME/.claude.json"
}

cfg() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2]))' "$HOME/.claude.json" "$1"; }

# 1. save đặt tên tự động từ email
login_as uuid-A alice@example.com
"$CS" save >/dev/null
[[ -f "$HOME/.claude-accounts/alice.json" ]] || fail "save không suy ra tên từ email"

# 2. save tài khoản thứ hai
login_as uuid-B bob@example.com
"$CS" save bob >/dev/null

# 3. status nhận diện đúng bằng accountUuid, kể cả khi config đã đổi nội dung khác
python3 -c '
import json;p="'"$HOME"'/.claude.json";d=json.load(open(p));d["numStartups"]=999;json.dump(d,open(p,"w"))'
"$CS" status | grep -q "Đang dùng: bob" || fail "status không nhận diện được account hiện tại"

# 4. switch: đổi đúng danh tính + credential
"$CS" alice >/dev/null
[[ "$(cfg userID)" == "user-uuid-A" ]] || fail "userID không được swap"
grep -q "tok-uuid-A" "$HOME/.claude/.credentials.json" || fail "credential không được swap"

# 5. các key thuộc về máy phải còn nguyên sau switch
[[ "$(cfg mcpServers)" == "{'keep-me': {}}" ]] || fail "switch làm mất mcpServers"
[[ "$(cfg projects)" != "None" ]] || fail "switch làm mất projects"

# 6. auto-save: profile bob phải được cập nhật trước khi rời đi
python3 -c '
import json;p=json.load(open("'"$HOME"'/.claude-accounts/bob.json"));assert p["credentials"]["refreshToken"]=="tok-uuid-B",p' \
  || fail "auto-save ghi sai credential"

# 7. next đi vòng tròn theo thứ tự alphabet: alice -> bob
"$CS" next >/dev/null
"$CS" status | grep -q "bob" || fail "next không đi tới profile kế tiếp"

# 8. list đánh dấu * đúng profile đang dùng
"$CS" list | grep -q '^\* bob' || fail "list đánh dấu sai profile hiện tại"

# 9. usage đọc được snapshot quota đã lưu
"$CS" usage | grep -q "42%" || fail "usage không đọc được snapshot quota"

# 10. tên profile độc hại bị chặn (chống path traversal)
if "$CS" save "../../evil" 2>/dev/null; then fail "chấp nhận tên profile chứa path traversal"; fi

# 11. quyền file: profile chứa refresh token nên phải 600 / thư mục 700
perm=$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' \
  "$HOME/.claude-accounts/bob.json")
[[ "$perm" == "600" ]] || fail "profile không phải chmod 600 (thực tế: $perm)"

# 12. remove
"$CS" remove alice >/dev/null
[[ ! -f "$HOME/.claude-accounts/alice.json" ]] || fail "remove không xoá profile"

# 13. backup ~/.claude.json được tạo trước mỗi lần ghi
ls "$HOME/.claude-accounts/backups"/claude.json.* >/dev/null 2>&1 || fail "không có backup config"

# 14. sync-sessions gộp mọi session về ĐÚNG thư mục <account>/<org> đang đăng nhập
#     (Desktop chỉ đọc thư mục đó), và không ghi đè bản đã có ở đích.
SESS="$HOME/sessions-giả"; export CLAUDE_SESSIONS_DIR="$SESS"   # tránh phụ thuộc đường dẫn theo OS
DST="$SESS/uuid-B/org-uuid-B"                  # đang đăng nhập bob = uuid-B
mkdir -p "$SESS/uuid-A/org-uuid-A" "$DST"
echo old > "$SESS/uuid-A/org-uuid-A/local_1.json"
echo new > "$DST/local_1.json"                 # đã có ở đích → phải giữ nguyên
echo x   > "$SESS/uuid-A/org-uuid-A/local_2.json"
echo x   > "$SESS/uuid-A/org-uuid-A/deleted_3.json"   # không phải local_* → bỏ qua
mkdir -p "$SESS/uuid-B/org-khac"                     # org khác cùng account → vẫn gộp về
echo x   > "$SESS/uuid-B/org-khac/local_4.json"
"$CS" sync-sessions >/dev/null
[[ -f "$DST/local_2.json" ]] || fail "sync-sessions không copy session của account khác"
[[ -f "$DST/local_4.json" ]] || fail "sync-sessions bỏ sót org khác của cùng account"
[[ "$(command cat "$DST/local_1.json")" == "new" ]] || fail "sync-sessions ghi đè file đã có"
[[ ! -e "$DST/deleted_3.json" ]] || fail "sync-sessions copy cả file không phải local_*"

echo "PASS — 14 checks"
