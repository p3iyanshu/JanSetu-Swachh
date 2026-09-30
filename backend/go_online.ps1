# Puts the JanSetu-Swachh backend on the internet with a Cloudflare quick
# tunnel and publishes the new address in dashboard/public/server.json.
# The website (Netlify redeploys from GitHub), the Android app and the admin
# exe all read server.json, so nothing needs rebuilding when the address
# changes. Run it via Start-JanSetu-Online.bat in the project root.

$ErrorActionPreference = "Stop"
$backendDir = $PSScriptRoot
$repoDir = Split-Path $backendDir -Parent
$logFile = Join-Path $env:TEMP "jansetu-tunnel.log"

function Write-Step($text) { Write-Host "  > $text" -ForegroundColor Cyan }
function Test-Url($url) {
    try { return (Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 $url).StatusCode -eq 200 } catch { return $false }
}

Write-Host ""
Write-Host "  JanSetu-Swachh - go online" -ForegroundColor Green
Write-Host ""

# 1. Backend
if (-not (Test-Url "http://127.0.0.1:8000/health")) {
    Write-Step "Starting the backend (separate window)..."
    Start-Process -FilePath (Join-Path $backendDir "venv\Scripts\python.exe") `
        -ArgumentList "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000" `
        -WorkingDirectory $backendDir -WindowStyle Minimized
    for ($i = 0; $i -lt 60 -and -not (Test-Url "http://127.0.0.1:8000/health"); $i++) { Start-Sleep 2 }
    if (-not (Test-Url "http://127.0.0.1:8000/health")) { throw "Backend did not start - run Start-JanSetu-Server.bat to see the error." }
}
Write-Step "Backend is running."

# 2. Tunnel
$cloudflared = @("C:\Program Files (x86)\cloudflared\cloudflared.exe", "C:\Program Files\cloudflared\cloudflared.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cloudflared) { throw "cloudflared is not installed. Run: winget install Cloudflare.cloudflared" }
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item $logFile -ErrorAction SilentlyContinue
Write-Step "Starting the Cloudflare tunnel (separate window)..."
Start-Process -FilePath $cloudflared -ArgumentList "tunnel", "--no-autoupdate", "--logfile", "`"$logFile`"", "--url", "http://localhost:8000" -WindowStyle Minimized

$url = $null
for ($i = 0; $i -lt 60 -and -not $url; $i++) {
    Start-Sleep 1
    if (Test-Path $logFile) {
        $match = Select-String -Path $logFile -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" | Select-Object -First 1
        if ($match) { $url = $match.Matches[0].Value }
    }
}
if (-not $url) { throw "Tunnel did not start - check your internet connection and try again." }
for ($i = 0; $i -lt 30 -and -not (Test-Url "$url/health"); $i++) { Start-Sleep 2 }
Write-Step "Backend is online at $url"

# 3. Publish the address
$configPath = Join-Path $repoDir "dashboard\public\server.json"
$config = "{`n  `"api_base_url`": `"$url/api/v1`"`n}`n"
[System.IO.File]::WriteAllText($configPath, $config)
Push-Location $repoDir
try {
    git add dashboard/public/server.json
    git commit -m "Update backend address to $url" | Out-Null
    git push | Out-Null
    Write-Step "Published - the website updates in about a minute."
} catch {
    Write-Host "  ! Could not push to GitHub: $_" -ForegroundColor Yellow
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "  Website:  https://jansetu-swachh.netlify.app" -ForegroundColor White
Write-Host "  Backend:  $url" -ForegroundColor White
Write-Host ""
Write-Host "  Keep this laptop on and connected. Closing the minimized backend or" -ForegroundColor Green
Write-Host "  tunnel windows takes the site offline; run this again to restore it." -ForegroundColor Green
Write-Host ""
