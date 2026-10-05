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
"$CS" sync-sessions >/dev/null                       # mặc định chỉ xem trước
[[ ! -e "$DST/local_2.json" ]] || fail "sync-sessions ghi khi chưa có --apply"
"$CS" sync-sessions --session local_2 --apply >/dev/null
[[ -f "$DST/local_2.json" && ! -e "$DST/local_4.json" ]] || fail "--session không chọn đúng một session"
"$CS" sync-sessions --apply >/dev/null
[[ -f "$DST/local_2.json" ]] || fail "sync-sessions không copy session của account khác"
[[ -f "$DST/local_4.json" ]] || fail "sync-sessions bỏ sót org khác của cùng account"
[[ "$(command cat "$DST/local_1.json")" == "new" ]] || fail "sync-sessions ghi đè file đã có"
[[ ! -e "$DST/deleted_3.json" ]] || fail "sync-sessions copy cả file không phải local_*"

# --from chỉ lấy session của đúng account nguồn
mkdir -p "$SESS/uuid-X/org-x"; echo x > "$SESS/uuid-X/org-x/local_5.json"
"$CS" sync-sessions --from uuid-A --apply >/dev/null
[[ ! -e "$DST/local_5.json" ]] || fail "--from lấy nhầm session của account khác"
"$CS" sync-sessions --from uuid-X --apply >/dev/null
[[ -f "$DST/local_5.json" ]] || fail "--from không lấy session của account nguồn"

# --update chỉ ghi đè khi nguồn có hoạt động mới hơn
printf '{"title":"new","lastActivityAt":2000000000000}' > "$SESS/uuid-A/org-uuid-A/local_6.json"
printf '{"title":"old","lastActivityAt":1000000000000}' > "$DST/local_6.json"
"$CS" sync-sessions --apply >/dev/null
grep -q '"old"' "$DST/local_6.json" || fail "ghi đè khi không có --update"
"$CS" sync-sessions --update --apply >/dev/null
grep -q '"new"' "$DST/local_6.json" || fail "--update không cập nhật bản cũ hơn"

# --- TUI: curses cần terminal thật nên chạy qua pty. Mỗi đối số là một lần gõ phím. ---
tui() {  # ghi toàn bộ output vào $SANDBOX/tui.out; trả exit code của claude-switch (124 = treo)
  python3 - "$CS" "$SANDBOX/tui.out" "$@" <<'PY'
import curses, fcntl, locale, os, pty, select, struct, sys, termios, time
cs, outf, *keys = sys.argv[1:]
env = dict(os.environ, TERM="xterm-256color")
curses.setupterm("xterm-256color", 1)
SGR = curses.tigetstr("kmous") == b"\x1b[<"  # SGR (1006) hay X10 cũ — tuỳ bản ncurses
def click(x, y):  # x, y tính từ 0
    if SGR:
        return f"\x1b[<0;{x+1};{y+1}M\x1b[<0;{x+1};{y+1}m".encode()
    return b"\x1b[M" + bytes([32, 33 + x, 33 + y]) + b"\x1b[M" + bytes([35, 33 + x, 33 + y])
for loc in ("en_US.UTF-8", "C.UTF-8"):  # có dấu tiếng Việt cần locale UTF-8
    try:
        locale.setlocale(locale.LC_ALL, loc); env["LC_ALL"] = loc; break
    except locale.Error:
        pass
pid, fd = pty.fork()
if pid == 0:
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 110, 0, 0))
    os.execve(sys.executable, [sys.executable, cs], env)
out = b""
def drain(t):
    global out
    end = time.time() + t
    while time.time() < end:
        if select.select([fd], [], [], 0.05)[0]:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                return
            if not chunk:
                return
            out += chunk
drain(0.8)
for k in keys:
    os.write(fd, click(*map(int, k[7:].split(","))) if k.startswith("@click:") else k.encode()); drain(0.3)
code = 124
for _ in range(60):
    r, st = os.waitpid(pid, os.WNOHANG)
    if r:
        code = os.WEXITSTATUS(st) if os.WIFEXITED(st) else 1
        break
    drain(0.05)
else:
    os.kill(pid, 9); os.waitpid(pid, 0)
open(outf, "wb").write(out)
sys.exit(code)
PY
}
shown() { grep -aq -- "$1" "$SANDBOX/tui.out"; }

# 15. không có TTY (pipe/script) → vẫn in help, không treo chờ phím
"$CS" </dev/null 2>&1 | grep -q "claude-switch" || fail "chạy không đối số, không TTY: không in help"

# Dựng lại 2 profile: alice, bob (bob đang dùng).
login_as uuid-A alice@example.com; "$CS" save >/dev/null
login_as uuid-B bob@example.com;   "$CS" save bob >/dev/null

# @pt.id SW-TUI-001-switch-by-keys
# @pt.item TUI liệt kê profile và chuyển bằng phím
# @pt.condition ở menu chính Enter mở "Chuyển tài khoản", k lên profile phía trên, Enter, rồi q
# @pt.expected danh sách có cả hai tên, tài khoản chuyển sang alice, thoát mã 0
# @pt.target _ui / do_switch
# @pt.method e2e
# @pt.legacy none
tui $'\r' k $'\r' q || fail "TUI treo hoặc thoát lỗi (rc=$?)"
shown alice && shown bob || fail "TUI không hiện danh sách profile"
"$CS" status | grep -q "Đang dùng: alice" || fail "TUI: Enter không chuyển profile"

# @pt.id SW-TUI-002-unsaved-guard
# @pt.item không âm thầm bỏ tài khoản chưa lưu khi chuyển
# @pt.condition đăng nhập tài khoản carol chưa lưu, nhấn Enter trên một profile rồi Esc
# @pt.expected hiện cảnh báo chưa lưu, Esc huỷ, vẫn đăng nhập carol
# @pt.target do_switch
# @pt.method e2e
# @pt.legacy none
login_as uuid-C carol@example.com
tui $'\r' $'\r' $'\x1b' $'\x1b' q || fail "TUI lỗi ở luồng tài khoản chưa lưu"
shown "chưa lưu" || fail "TUI không cảnh báo tài khoản chưa lưu"
[[ "$(cfg userID)" == "user-uuid-C" ]] || fail "TUI chuyển dù người dùng đã huỷ"

# @pt.id SW-TUI-003-save-name-validation
# @pt.item ô nhập tên khi lưu
# @pt.condition mục 3 (Lưu): nhập tên có dấu '/', sau đó nhập tên hợp lệ
# @pt.expected tên sai bị báo lỗi và không tạo file; tên đúng tạo profile
# @pt.target do_save
# @pt.method e2e
# @pt.legacy none
tui 3 a/b $'\r' 3 carol $'\r' q || fail "TUI lỗi ở luồng lưu"
shown "Tên không hợp lệ" || fail "TUI không báo tên sai"
[[ -f "$HOME/.claude-accounts/carol.json" ]] || fail "TUI không lưu profile carol"
ls "$HOME/.claude-accounts" | grep -q '/' && fail "tên chứa / lọt qua"

# @pt.id SW-TUI-004-session-picker
# @pt.item chọn session trong TUI rồi gộp
# @pt.condition có nhiều session ở account khác, mục 5 (Đồng bộ), Space đánh dấu dòng đầu, Enter
# @pt.expected chỉ session đã đánh dấu (mới nhất) được copy về đúng thư mục đích
# @pt.target do_sessions / apply_sync
# @pt.method e2e
# @pt.legacy none
mkdir -p "$SESS/uuid-A/org-uuid-A"
printf '{"title":"Phiên chín","lastActivityAt":4000000000000}' > "$SESS/uuid-A/org-uuid-A/local_9.json"
tui 5 ' ' $'\r' q || fail "TUI lỗi ở màn hình chọn session"
CDST="$SESS/uuid-C/org-uuid-C"
[[ -f "$CDST/local_9.json" ]] || fail "TUI không gộp session đã chọn"
[[ "$(ls "$CDST" | wc -l | tr -d ' ')" == "1" ]] || fail "TUI gộp cả session chưa đánh dấu"

# @pt.id SW-SAFE-001-doctor-and-corrupt-profile
# @pt.item doctor phát hiện lỗi; list không sập khi có profile hỏng
# @pt.condition cấu hình sạch, rồi có biến ANTHROPIC_API_KEY, rồi có file profile hỏng
# @pt.expected sạch → exit 0; biến đặt → cảnh báo; profile hỏng → exit 1 và list vẫn chạy
# @pt.target cmd_doctor / load_rows
# @pt.method e2e
# @pt.legacy none
env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN "$CS" doctor >/dev/null || fail "doctor báo lỗi trên cấu hình sạch"
ANTHROPIC_API_KEY=x "$CS" doctor | grep -q "ANTHROPIC_API_KEY" || fail "doctor không cảnh báo biến ghi đè"
echo '{hỏng' > "$HOME/.claude-accounts/broken.json"; chmod 600 "$HOME/.claude-accounts/broken.json"
if "$CS" doctor >/dev/null; then fail "doctor bỏ sót profile hỏng"; fi
"$CS" list >/dev/null || fail "list sập khi có profile hỏng"
rm "$HOME/.claude-accounts/broken.json"

# @pt.id SW-SAFE-002-lock
# @pt.item hai lệnh ghi không chạy chồng
# @pt.condition một tiến trình giữ khoá trong khi chạy save
# @pt.expected save bị từ chối thay vì ghi đè
# @pt.target lock
# @pt.method e2e
# @pt.legacy none
python3 -c 'import fcntl,os,time;f=open(os.path.expanduser("~/.claude-accounts/.lock"),"w");fcntl.flock(f,fcntl.LOCK_EX);time.sleep(3)' &
LOCKPID=$!; sleep 1
if "$CS" save zzz >/dev/null 2>&1; then fail "save chạy chồng khi đang có khoá"; fi
wait "$LOCKPID"
"$CS" save zzz >/dev/null || fail "save không chạy lại được sau khi nhả khoá"

# @pt.id SW-TUI-005-menu-lists-every-function
# @pt.item menu chính hiện đủ mọi chức năng để chọn
# @pt.condition mở TUI rồi thoát
# @pt.expected cả 9 mục menu xuất hiện trên màn hình
# @pt.target draw_home / MENU
# @pt.method e2e
# @pt.legacy none
tui q || fail "TUI không thoát được bằng q"
for item in "Chuyển tài khoản" "Tài khoản kế tiếp" "Lưu tài khoản hiện tại" "Quota & usage" \
            "Đồng bộ session" "Xoá profile" "Kiểm tra cấu hình" "Trợ giúp" "Thoát"; do
  shown "$item" || fail "menu thiếu mục: $item"
done

# @pt.id SW-TUI-006-number-key-and-back
# @pt.item phím số mở màn hình con, Esc quay lại menu
# @pt.condition phím 7 (Kiểm tra cấu hình), Esc, rồi q
# @pt.expected thấy kết quả doctor, sau Esc vẫn ở menu và q thoát mã 0
# @pt.target act / show_text
# @pt.method e2e
# @pt.legacy none
tui 7 $'\x1b' q || fail "TUI lỗi ở màn hình doctor"
shown "Không phát hiện lỗi\|lỗi cần sửa" || fail "màn hình doctor không hiện kết quả"

# @pt.id SW-TUI-007-mouse
# @pt.item bấm chuột vào mục menu
# @pt.condition terminal 110x30: bấm dòng "Kiểm tra cấu hình" (menu bắt đầu ở hàng 11, mục 7 → hàng 17)
# @pt.expected mở màn hình doctor như khi nhấn phím 7
# @pt.target getkey / draw_home
# @pt.method e2e
# @pt.legacy none
tui @click:30,17 $'\x1b' q || fail "TUI lỗi khi bấm chuột"
shown "Không phát hiện lỗi\|lỗi cần sửa" || fail "bấm chuột không mở được mục menu"

echo "PASS — 29 checks"
