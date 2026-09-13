#
# Cài claude-switch trên Windows vào ~/.local/bin
# Tự động phát hiện phiên bản hệ điều hành, môi trường Python,
# và các đường dẫn dữ liệu của Claude Code / Claude Desktop.
#
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Phát hiện hệ điều hành
$OSInfo = [System.Environment]::OSVersion
Write-Host "==> Phát hiện hệ điều hành: Windows ($($OSInfo.VersionString))" -ForegroundColor Cyan

# 2. Kiểm tra môi trường Python (yêu cầu >= 3.8)
$PythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCmd = "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonCmd = "py -3"
}

if (-not $PythonCmd) {
    Write-Error "[ERROR] Không tìm thấy Python trong PATH. Vui lòng cài đặt Python 3.8+ từ https://python.org hoặc Microsoft Store."
    exit 1
}

$PyVerCheck = & ($PythonCmd -split ' ')[0] ($PythonCmd -split ' ')[1..($PythonCmd.Length)] -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}'); exit(0 if sys.version_info >= (3, 8) else 1)" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "[ERROR] Yêu cầu Python 3.8 trở lên (hiện tại: $PyVerCheck)."
    exit 1
}
Write-Host "==> Python: $PythonCmd ($PyVerCheck)" -ForegroundColor Green

# 3. Kiểm tra cấu hình Claude Code trên máy
$ClaudeConfig = Join-Path $HOME ".claude.json"
$ClaudeCreds = Join-Path $HOME ".claude\.credentials.json"
if (Test-Path $ClaudeConfig) {
    Write-Host "==> Claude Code: Đã tìm thấy cấu hình ($ClaudeConfig)" -ForegroundColor Green
} else {
    Write-Host "==> Claude Code: [Lưu ý] Chưa tìm thấy $ClaudeConfig. Hãy đăng nhập tài khoản bằng lệnh 'claude' trước khi lưu profile." -ForegroundColor Yellow
}

# 4. Kiểm tra Claude Desktop (nếu có)
$MsixSessions = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code-sessions"
$StandardSessions = Join-Path $env:APPDATA "Claude\claude-code-sessions"
if (Test-Path $MsixSessions) {
    Write-Host "==> Claude Desktop: Phát hiện bản Microsoft Store (MSIX)" -ForegroundColor Green
} elseif (Test-Path $StandardSessions) {
    Write-Host "==> Claude Desktop: Phát hiện bản tiêu chuẩn ($StandardSessions)" -ForegroundColor Green
} else {
    Write-Host "==> Claude Desktop: Chưa phát hiện thư mục dữ liệu Desktop (sẽ tự động tạo khi chạy Claude Desktop)" -ForegroundColor Gray
}

# 5. Cài đặt vào ~/.local/bin
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $ScriptDir "claude-switch"
$VersionSrc = Join-Path $ScriptDir "VERSION"

$Dest = Join-Path $HOME ".local\bin"
if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

Copy-Item -Path $Src -Destination (Join-Path $Dest "claude-switch") -Force
if (Test-Path $VersionSrc) {
    Copy-Item -Path $VersionSrc -Destination (Join-Path $Dest "VERSION") -Force
}

$CmdWrapper = Join-Path $Dest "claude-switch.cmd"
$CmdContent = @"
@echo off
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python "%~dp0claude-switch" %*
) else (
    py -3 "%~dp0claude-switch" %*
)
"@
Set-Content -Path $CmdWrapper -Value $CmdContent -Encoding ASCII

# Kiểm tra PATH
$NormalizedDest = (Resolve-Path $Dest).Path.TrimEnd('\')
$InPath = ($env:PATH -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') }) -contains $NormalizedDest

if (-not $InPath) {
    Write-Host "[!] $Dest chưa có trong PATH của môi trường hiện tại." -ForegroundColor Yellow
    Write-Host "    Thêm vào User PATH bằng lệnh:" -ForegroundColor Yellow
    Write-Host "    `$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')" -ForegroundColor Cyan
    Write-Host "    [Environment]::SetEnvironmentVariable('Path', `"`$userPath;$Dest`", 'User')" -ForegroundColor Cyan
}

Write-Host "[OK] Đã cài đặt vào: $Dest\claude-switch" -ForegroundColor Green
Write-Host ""

# In trợ giúp
& $CmdWrapper help
