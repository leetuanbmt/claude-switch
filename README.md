<h1 align="center">claude-switch</h1>

<p align="center">
  Chuyển đổi nhiều tài khoản Claude Code mà không phải đăng nhập lại.<br>
  Một file Python, chỉ dùng stdlib.
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey">
  <img alt="python" src="https://img.shields.io/badge/python-3.8%2B-blue">
  <img alt="dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
  <img alt="tests" src="https://img.shields.io/badge/tests-14%2F14-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

---

Có nhiều tài khoản Claude Code (cá nhân, công ty, team khác) thì mỗi lần đổi phải
`/login` lại từ đầu. `claude-switch` lưu credential của từng tài khoản thành profile
và hoán đổi trong chưa tới một giây — giữ nguyên settings, hooks, plugins và toàn bộ
lịch sử hội thoại.

## Cài đặt

```bash
git clone https://github.com/leetuanbmt/claude-switch.git
cd claude-switch && ./install.sh
```

Symlink vào thư mục đầu tiên có trong `PATH` (`~/.local/bin`, `/usr/local/bin`,
`/opt/homebrew/bin`). Yêu cầu duy nhất là `python3` — macOS và Ubuntu cài sẵn.

## Bắt đầu

```bash
claude-switch save            # lưu tài khoản đang đăng nhập, tên lấy từ email
claude                        # /login bằng tài khoản thứ hai
claude-switch save work       # lưu tiếp, đặt tên tuỳ ý
claude-switch work            # chuyển sang
```

Sau khi switch phải **thoát và mở lại Claude Code** — phiên đang chạy giữ token trong RAM.

## Lệnh

| Lệnh | Việc nó làm |
|---|---|
| `save [name]` | Lưu tài khoản đang đăng nhập thành profile. Bỏ trống `name` thì lấy phần trước `@` của email. |
| `<name>` | Chuyển sang profile đó (viết tắt của `use <name>`). |
| `list` | Danh sách profile, `*` đánh dấu cái đang dùng. |
| `status` | Tài khoản đang đăng nhập. |
| `usage` | Bảng quota 5h / 7 ngày của mọi profile. |
| `next` | Chuyển sang profile kế tiếp theo vòng tròn. |
| `remove <name>` | Xoá profile (tài khoản trên server không bị ảnh hưởng). |
| `sync-sessions` | Gộp sidebar session của Claude Desktop về tài khoản đang dùng. |
| `version` | Phiên bản, đọc từ file `VERSION`. |

```console
$ claude-switch list
  personal       me@gmail.com                     me@gmail.com's Organization
* work           me@company.com                   ACME
  client         me@client.io                     Client Co

$ claude-switch usage
PROFILE        EMAIL                        5H     7D     SNAPSHOT
personal       me@gmail.com                   ?      ?    70h trước
work           me@company.com                12%    41%   2h trước   reset 29/08 21:59
client         me@client.io                   0%     3%   111h trước reset 30/08 08:30
```

Số liệu `usage` là snapshot lúc profile được lưu, tự cập nhật mỗi lần switch — nên
không phải đăng nhập từng tài khoản chỉ để xem còn bao nhiêu quota. Muốn số realtime
của tài khoản đang dùng thì `claude` → `/usage`.

## Cách hoạt động

Chỉ hoán đổi đúng phần thuộc về *tài khoản*, còn lại thuộc về *máy* nên giữ nguyên:

| Hoán đổi | Giữ nguyên |
|---|---|
| OAuth token — macOS Keychain `Claude Code-credentials`, hoặc `~/.claude/.credentials.json` | Toàn bộ `~/.claude/` — settings, `CLAUDE.md`, hooks, plugins, projects |
| 2 key `oauthAccount` + `userID` trong `~/.claude.json` | Mọi key khác trong `~/.claude.json` — `mcpServers`, `projects`, cache |

Vì lịch sử hội thoại và cấu hình nằm ngoài phạm vi swap, mọi tài khoản dùng chung
chúng và mỗi lần switch chỉ ghi vài KB.

`~/.claude.json` được backup (giữ 10 bản gần nhất) vào `~/.claude-accounts/backups/`
trước mỗi lần ghi, và ghi bằng `os.replace` nên không thể để lại file hỏng giữa chừng.

## sync-sessions — vì sao Desktop mất danh sách session

Nội dung hội thoại nằm ở `~/.claude/projects/<cwd-slug>/<sessionId>.jsonl`, dùng chung
cho mọi tài khoản. Nhưng Claude Desktop lưu metadata để dựng sidebar (title, model,
`cwd`, `cliSessionId`) ở nơi khác, chia theo tài khoản:

```
~/Library/Application Support/Claude/claude-code-sessions/<accountUuid>/<orgUuid>/local_*.json
```

Desktop chỉ đọc **đúng một** thư mục — của account **và** org đang đăng nhập. Đổi tài
khoản là sidebar trống, dù transcript còn nguyên vẹn.

`sync-sessions` copy mọi `local_*.json` từ các thư mục khác vào thư mục đang active:

- **Đổi cả `orgUuid`**, không giữ org gốc. Giữ nguyên thì file rơi vào thư mục Desktop
  không bao giờ đọc tới.
- Không ghi đè file trùng tên — bản ở đích mới hơn (`lastFocusedAt`, title đã sửa).
- Bỏ qua `deleted_*` và `scheduled-tasks.json`.

Chạy xong phải **⌘Q Claude Desktop rồi mở lại**, vì sidebar dựng lúc khởi động. Mỗi
lần switch sang account hoặc org khác thì chạy lại, do thư mục đích đổi theo org.

> **Giới hạn:** lệnh chỉ *di chuyển* danh sách đã có, không *tạo* mục mới. Session chạy
> bằng `claude` trong terminal chưa bao giờ có `local_*.json` nên Desktop không liệt kê.
> Từ CLI thì không cần lệnh này — `cd <project> && claude --resume <sessionId>` luôn thấy
> đủ session.

## Nền tảng

| | Credential | Sidebar Desktop | Trạng thái |
|---|---|---|---|
| macOS | Keychain `Claude Code-credentials` | `~/Library/Application Support/Claude/…` | Đã test (macOS 26) |
| Linux / WSL | `~/.claude/.credentials.json` | `~/.config/Claude/…` | Đã test (Ubuntu 24.04, Python 3.12) |
| Windows | `~/.claude/.credentials.json` | `%APPDATA%/Claude/…` | Chưa hỗ trợ — dùng WSL |

Đặt `CLAUDE_SESSIONS_DIR` nếu Claude Desktop cài ở đường dẫn khác mặc định.

Windows chưa hỗ trợ vì hai lý do: chưa xác minh Claude Code bản Windows lưu OAuth
token ở file hay Credential Manager, và `chmod 600` vô hiệu trên NTFS nên refresh
token sẽ nằm không có bảo vệ quyền file.

## Bảo mật

`~/.claude-accounts/` (chmod 700) chứa **refresh token** ở dạng plaintext, mỗi file
chmod 600. Đừng commit thư mục này, cũng đừng để iCloud hay Dropbox sync nó.

Muốn mã hoá thì bọc `openssl enc` quanh `read_creds`/`write_creds` — chưa làm vì sẽ
phải nhập passphrase mỗi lần switch.

Trên macOS, `security add-generic-password -w` nhận token qua `argv` nên nó lộ trong
`ps` khoảng vài mili giây. Chấp nhận được trên máy cá nhân; máy nhiều người dùng thì
cần gọi thẳng Security.framework.

## Phát triển

```bash
./test.sh    # 14 checks
```

Test dựng một `$HOME` tạm và ép backend credential dạng file, nên Keychain thật không
bao giờ bị ghi và tài khoản thật không bị đụng tới. `CLAUDE_SESSIONS_DIR` cũng trỏ vào
sandbox nên bộ test chạy như nhau trên mọi OS.

```
claude-switch    # toàn bộ chương trình, một file Python
install.sh       # symlink vào PATH
test.sh          # bộ test, chạy qua CLI nên không phụ thuộc chi tiết cài đặt
VERSION          # nguồn duy nhất của số phiên bản
```

## Giấy phép

[MIT](LICENSE) © Minh Tuấn
