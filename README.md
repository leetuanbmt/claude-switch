<h1 align="center">agents-switch</h1>

<p align="center">
  Chuyển đổi đa tài khoản cho các AI Coding Agents (Claude Code, OpenAI Codex) mà không phải đăng nhập lại.<br>
  Tham khảo cơ chế từ <a href="https://github.com/loongphy/codex-auth">codex-auth</a> cho OpenAI Codex.<br>
  Một file Python duy nhất, chỉ dùng stdlib.
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey">
  <img alt="python" src="https://img.shields.io/badge/python-3.8%2B-blue">
  <img alt="dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
  <img alt="tests" src="https://img.shields.io/badge/tests-53%2F53-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

---

Khi làm việc với nhiều tài khoản AI Coding Agents (tài khoản cá nhân, công ty, khách hàng khác nhau), mỗi lần đổi tài khoản bạn thường phải logout và login lại từ đầu rất mất thời gian.

`agents-switch` giải quyết vấn đề này bằng cách lưu trữ credential của từng tài khoản thành các profile riêng biệt và hoán đổi trong chưa tới một giây — giữ nguyên settings, hooks, plugins và lịch sử làm việc.

Công cụ hỗ trợ nhiều AI Agent clients:
- **Claude Code (`claude`)**: Quản lý OAuth token trong macOS Keychain hoặc `~/.claude/.credentials.json`, `~/.claude.json`, đồng bộ session Claude Desktop, theo dõi snapshot quota 5H/7D.
- **OpenAI Codex (`codex`)**: Tham khảo từ `codex-auth`, quản lý `~/.codex/auth.json`, tự động giải mã JWT để lấy email/plan/account_id, hỗ trợ chuyển nhanh tài khoản trước đó (`switch -`), quản lý alias, export/import, tương thích Codex CLI, VS Code extension và Codex App.

---

## Cài đặt

```bash
git clone https://github.com/leetuanbmt/claude-switch.git
cd claude-switch && ./install.sh
```

Script sẽ tự động tạo symlink vào thư mục đầu tiên có trong `PATH` (`~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`):
- `agents-switch`: Hub trung tâm quản lý đa client.
- `claude-switch`: Lệnh tắt tương thích ngược chuyên cho Claude Code.
- `codex-switch`: Lệnh tắt chuyên cho OpenAI Codex.

Yêu cầu duy nhất là `python3` (3.8+) — có sẵn trên macOS và Linux/Ubuntu. Không cần cài thêm bất kỳ package nào.

---

## Bắt đầu nhanh

### 1. Dùng với Claude Code

```bash
claude-switch save            # Lưu tài khoản Claude đang đăng nhập (tự lấy tên từ email)
claude                        # Đăng nhập tài khoản Claude thứ 2
claude-switch save work       # Lưu tiếp với tên 'work'
claude-switch work            # Chuyển sang tài khoản 'work'
```

*Lưu ý: Sau khi switch Claude Code, hãy thoát và mở lại terminal/Claude Code để nhận token mới.*

### 2. Dùng với OpenAI Codex (tham khảo codex-auth)

```bash
codex-switch save             # Lưu tài khoản Codex hiện tại từ ~/.codex/auth.json
codex login                   # Đăng nhập tài khoản Codex thứ 2
codex-switch save openai-work # Lưu với tên 'openai-work'
codex-switch switch -         # Chuyển đổi nhanh về tài khoản trước đó!
codex-switch alias set openai-work work  # Gán alias 'work'
codex-switch switch work      # Chuyển nhanh bằng alias
```

*Lưu ý: Khởi động lại Codex CLI, VS Code extension hoặc Codex App sau khi switch.*

### 3. Dùng với Hub agents-switch

```bash
agents-switch clients         # Liệt kê các client được hỗ trợ và trạng thái
agents-switch status          # Xem tài khoản đang active trên mọi client
agents-switch doctor          # Kiểm tra cấu hình toàn bộ client
agents-switch claude list     # Liệt kê profile Claude
agents-switch codex list      # Liệt kê profile Codex
```

---

## Giao diện tương tác (TUI)

Chạy `agents-switch` (hoặc `claude-switch`, `codex-switch`) không đối số trong terminal để mở giao diện toàn màn hình:

```
                    ⇄  agents-switch
      chuyển đổi tài khoản AI Coding Agents · v2.0.0

          [ Client: Claude Code ]  (Tab / c: đổi)
              ● work  ·  me@company.com
           5H ██░░░░  33%    7D ██░░░░  41%

        ▸ 1  Chuyển tài khoản         chọn profile rồi chuyển
          2  Tài khoản kế tiếp        chuyển vòng tròn sang profile sau
          3  Lưu tài khoản hiện tại   thành profile mới hoặc cập nhật
          4  Quota & usage            5H / 7 ngày của mọi profile
          5  Đồng bộ session          gộp sidebar Desktop, chọn từng cái
          6  Xoá profile              chọn profile cần xoá
          7  Kiểm tra cấu hình        quyền file, biến ghi đè, profile hỏng
          8  Trợ giúp                 phím tắt và cách hoạt động
          c  Đổi client               chuyển sang OpenAI Codex
          q  Thoát
```

| Thao tác | Hành động |
|---|---|
| `↑` `↓` / `j` `k` | Chọn mục |
| `Tab` / `c` | **Đổi client làm việc** giữa Claude Code và OpenAI Codex ngay trong TUI |
| `Enter` | Mở mục / xác nhận chuyển |
| `1`–`8` | Mở thẳng mục theo số phím tắt |
| `Esc` | Quay lại màn hình trước |
| Chuột | Bấm chọn mục, bấm nút hành động chân màn hình, cuộn bằng bánh xe |

---

## Bảng lệnh CLI

### Lệnh toàn cục `agents-switch`

| Lệnh | Mô tả |
|---|---|
| `agents-switch` | Mở TUI đa client |
| `agents-switch clients` | Liệt kê danh sách AI agent clients và trạng thái |
| `agents-switch client [name]` | Xem hoặc đặt client mặc định (`claude` hoặc `codex`) |
| `agents-switch status` | Hiển thị tài khoản active trên tất cả clients |
| `agents-switch doctor` | Kiểm tra toàn diện tất cả clients |
| `agents-switch <client> <cmd>` | Thực thi lệnh cho client chỉ định (`claude` hoặc `codex`) |

### Lệnh cho Claude Code (`claude-switch` hoặc `agents-switch claude`)

| Lệnh | Mô tả |
|---|---|
| `save [name]` | Lưu tài khoản đang đăng nhập thành profile (tự sinh tên nếu bỏ trống) |
| `<name>` / `use <name>` | Chuyển sang profile đó |
| `list` | Danh sách profile, `*` đánh dấu tài khoản đang dùng |
| `status` | Tài khoản đang đăng nhập |
| `usage` | Bảng quota 5H / 7 ngày của mọi profile |
| `next` | Chuyển sang profile kế tiếp theo vòng tròn alphabet |
| `remove <name>` | Xoá profile |
| `sync-sessions` | Xem trước / gộp danh sách session Claude Desktop về tài khoản active |
| `doctor` | Kiểm tra quyền file, biến môi trường (`ANTHROPIC_*`), profile hỏng |

### Lệnh cho OpenAI Codex (`codex-switch` hoặc `agents-switch codex`)

| Lệnh | Mô tả |
|---|---|
| `save [name]` | Lưu tài khoản từ `~/.codex/auth.json` (tự giải mã JWT lấy email/plan) |
| `switch <query>` | Chuyển sang profile theo tên, alias hoặc email |
| `switch -` | **Quay lại tài khoản trước đó** (tính năng từ `codex-auth`) |
| `list` | Danh sách profile Codex, kèm Alias, Email, Plan, Auth Mode |
| `status` | Tài khoản Codex đang đăng nhập và gói dịch vụ (Pro, Team, etc.) |
| `next` | Chuyển sang profile Codex kế tiếp |
| `alias set <q> <alias>` | Gán alias cho profile để switch nhanh |
| `alias clear <q>` | Xoá alias của profile |
| `login [--device-auth]` | Chạy `codex login` rồi tự động lưu profile |
| `export [dir]` | Xuất các snapshot auth thành file `*.auth.json` |
| `import <path>` | Nhập file hoặc thư mục `*.auth.json` vào profile |
| `remove <name>` / `--all` | Xoá profile (hoặc xoá toàn bộ với `--all`) |
| `doctor` | Kiểm tra cấu hình Codex, quyền file, biến `OPENAI_API_KEY` |

---

## Cách hoạt động & Bảo mật

1. **Phạm vi hoán đổi:**
   - **Claude Code:** Chỉ hoán đổi OAuth token (Keychain hoặc `~/.claude/.credentials.json`) và 2 key `oauthAccount` + `userID` trong `~/.claude.json`. Giữ nguyên `~/.claude/` (settings, MCP servers, projects, hooks).
   - **OpenAI Codex:** Hoán đổi file `~/.codex/auth.json`. Hỗ trợ cả ChatGPT Subscription OAuth và OpenAI API Key.
2. **Bảo mật:**
   - Thư mục profile `~/.claude-accounts` và `~/.codex-accounts` được bảo vệ với quyền `chmod 700`.
   - File profile chứa refresh token được bảo vệ với `chmod 600`.
   - Ghi dữ liệu dạng atomic (`os.replace`) tránh hỏng file khi bị ngắt tiến trình.
   - Sao lưu tự động (giữ 10 bản gần nhất) vào thư mục `backups/` trước mỗi lần ghi đè.
   - Khoá file chống xung đột (`fcntl.flock`) khi có nhiều lệnh chạy cùng lúc.

---

## Kiểm thử

Bộ kiểm thử tự động gồm 53 checks bao phủ toàn bộ các tính năng của Claude Code và OpenAI Codex:

```bash
./test.sh
```

Kết quả:
```console
PASS — 53 checks (All Claude Code + OpenAI Codex multi-client tests passed)
```
