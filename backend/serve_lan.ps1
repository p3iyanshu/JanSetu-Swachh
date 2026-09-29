# Starts the JanSetu-Swachh backend so phones and admin PCs on the same Wi-Fi
# can use it. Run it via Start-JanSetu-Server.bat in the project root.
#
#  - checks PostgreSQL is running
#  - opens the Windows Firewall for the API (8000), voice (8001) and LAN
#    auto-discovery (UDP 45678) ports when run as Administrator
#  - starts the voice-to-text service in its own window (if set up)
#  - prints this computer's Wi-Fi address(es) for the apps
#  - runs the API on 0.0.0.0:8000 (reachable from other devices)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Step($text) { Write-Host "  > $text" -ForegroundColor Cyan }
function Write-Warn($text) { Write-Host "  ! $text" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  JanSetu-Swachh server" -ForegroundColor Green
Write-Host "  =====================" -ForegroundColor Green
Write-Host ""

# 1. Python environment
if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Step "First run: creating Python environment and installing packages (this takes a few minutes)..."
    python -m venv venv
    .\venv\Scripts\python.exe -m pip install -r requirements.txt
}
if (-not (Test-Path ".env")) {
    Write-Warn "backend\.env is missing. Copy .env.example to .env and set DATABASE_URL first."
    Read-Host "Press Enter to exit"
    exit 1
}

# 2. PostgreSQL
$pg = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $pg) {
    Write-Warn "PostgreSQL service not found - make sure the database in backend\.env is reachable."
} elseif ($pg.Status -ne "Running") {
    Write-Step "Starting PostgreSQL ($($pg.Name))..."
    try { Start-Service $pg.Name } catch { Write-Warn "Could not start PostgreSQL - start the '$($pg.Name)' service manually (needs Administrator)." }
}

# 3. Firewall (needs Administrator; harmless to skip if rules already exist)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$rules = @(
    @{ Name = "JanSetu-Swachh API (TCP 8000)"; Protocol = "TCP"; Port = 8000 },
    @{ Name = "JanSetu-Swachh Voice (TCP 8001)"; Protocol = "TCP"; Port = 8001 },
    @{ Name = "JanSetu-Swachh Discovery (UDP 45678)"; Protocol = "UDP"; Port = 45678 }
)
$missing = $rules | Where-Object { -not (Get-NetFirewallRule -DisplayName $_.Name -ErrorAction SilentlyContinue) }
if ($missing) {
    if ($isAdmin) {
        foreach ($rule in $missing) {
            New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow -Protocol $rule.Protocol -LocalPort $rule.Port -Profile Any | Out-Null
        }
        Write-Step "Firewall opened for ports 8000, 8001 and 45678."
    } else {
        Write-Warn "Firewall rules not added (not running as Administrator)."
        Write-Warn "If Windows asks to allow Python on the network, tick BOTH Private and Public and click Allow."
        Write-Warn "Or right-click Start-JanSetu-Server.bat > Run as administrator once."
    }
}

# 4. Voice-to-text service (optional)
$voiceDir = Join-Path $PSScriptRoot "..\voice-backend"
if (Test-Path (Join-Path $voiceDir "venv\Scripts\python.exe")) {
    Write-Step "Starting voice-to-text service on port 8001 (separate window)..."
    Start-Process -FilePath (Join-Path $voiceDir "venv\Scripts\python.exe") `
        -ArgumentList "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001" `
        -WorkingDirectory $voiceDir -WindowStyle Minimized
}

# 5. Addresses for the apps
$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -ne "WellKnown" } |
    Select-Object -ExpandProperty IPAddress
Write-Host ""
Write-Host "  Phones and admin PCs must be on the SAME Wi-Fi / hotspot as this computer." -ForegroundColor Green
Write-Host "  The apps find this server automatically. If they don't, enter this address" -ForegroundColor Green
Write-Host "  in the app's Server address setting:" -ForegroundColor Green
foreach ($ip in $addresses) { Write-Host "        $($ip):8000" -ForegroundColor White }
Write-Host ""
Write-Host "  Keep this window open while using the apps. Press Ctrl+C to stop." -ForegroundColor Green
Write-Host ""

# 6. API server
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
