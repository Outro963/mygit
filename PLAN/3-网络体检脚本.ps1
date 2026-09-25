# MyGit network / GitHub connectivity check
# Run in YOUR OWN terminal (not inside a restricted sandbox):
#   powershell -ExecutionPolicy Bypass -File F:\MyGit\PLAN\3-网络体检脚本.ps1
# ASCII-only output on purpose: Windows PowerShell 5.1 mis-decodes UTF-8 .ps1 without BOM.

$ErrorActionPreference = 'SilentlyContinue'

function Line($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }

Line "1. DNS resolution"
foreach ($h in @('github.com','api.github.com','codeload.github.com','ssh.github.com','gitee.com','objects.githubusercontent.com')) {
    $ip = (Resolve-DnsName $h -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress
    if ($ip) { Write-Host ("  {0,-32} -> {1}" -f $h, $ip) } else { Write-Host ("  {0,-32} -> DNS FAIL" -f $h) -ForegroundColor Red }
}

Line "2. TCP reachability"
$targets = @(
    @('github.com',443), @('api.github.com',443), @('codeload.github.com',443),
    @('ssh.github.com',443), @('github.com',22),
    @('140.82.112.3',443), @('140.82.113.4',443), @('140.82.121.4',443),
    @('gitee.com',443)
)
foreach ($t in $targets) {
    $ok = Test-NetConnection -ComputerName $t[0] -Port $t[1] -InformationLevel Quiet -WarningAction SilentlyContinue
    $label = "{0}:{1}" -f $t[0], $t[1]
    if ($ok) { Write-Host ("  {0,-32} OK" -f $label) -ForegroundColor Green }
    else     { Write-Host ("  {0,-32} BLOCKED/TIMEOUT" -f $label) -ForegroundColor Red }
}

Line "3. HTTPS probe"
foreach ($u in @('https://github.com/login','https://api.github.com','https://gitee.com','https://www.baidu.com')) {
    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
        Write-Host ("  {0,-32} HTTP {1}" -f $u, $r.StatusCode) -ForegroundColor Green
    } catch {
        Write-Host ("  {0,-32} FAIL: {1}" -f $u, $_.Exception.Message) -ForegroundColor Red
    }
}

Line "4. Proxy configuration"
$winhttp = (netsh winhttp show proxy) -join ' '
Write-Host "  WinHTTP: $winhttp"
$ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Write-Host ("  ProxyEnable = {0}" -f $ie.ProxyEnable)
Write-Host ("  ProxyServer = {0}" -f $ie.ProxyServer)
$listening = @()
foreach ($p in @(10792,7890,7897,10809,10808,1080,8080,2080)) {
    $c = New-Object System.Net.Sockets.TcpClient
    if ($c.ConnectAsync('127.0.0.1',$p).Wait(800) -and $c.Connected) { $listening += $p }
    $c.Close()
}
if ($listening.Count -gt 0) { Write-Host ("  Local proxy ports LISTENING: {0}" -f ($listening -join ', ')) -ForegroundColor Yellow }
else { Write-Host "  Local proxy ports listening: none" }

Line "5. hosts file entries"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entries = (Get-Content $hostsPath) | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' -and $_ -match 'github|gitee' }
if ($entries) { $entries | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  none (clean)" -ForegroundColor Green }

Line "6. git identity / remote"
Write-Host ("  user.name  = {0}" -f (git config --global --get user.name))
Write-Host ("  user.email = {0}" -f (git config --global --get user.email))
Write-Host ("  cred.helper= {0}" -f (git config --global --get credential.helper))
$remotes = git -C F:\MyGit remote -v
if ($remotes) { $remotes | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  no remote in F:\MyGit" }

Line "VERDICT"
$gh = Test-NetConnection -ComputerName github.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
$alternate = (Test-NetConnection -ComputerName 140.82.112.3 -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue) -or
             (Test-NetConnection -ComputerName 140.82.113.4 -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)
$gitee = Test-NetConnection -ComputerName gitee.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($gh) {
    Write-Host "  github.com:443 is reachable." -ForegroundColor Green
    Write-Host "  If web login still fails: use an incognito window, or the account may need email verification." -ForegroundColor Yellow
    Write-Host "  NOTE: git push NEVER accepts your account password. Use a Personal Access Token or an SSH key." -ForegroundColor Yellow
} elseif ($alternate) {
    Write-Host "  github.com IP is blocked, but other GitHub IPs work." -ForegroundColor Yellow
    Write-Host "  ACTION: change DNS to 223.5.5.5, then map github.com in hosts to 140.82.112.3 (see PLAN\2-远程仓库与GitHub登录.md step 3)." -ForegroundColor Yellow
} elseif ($gitee) {
    Write-Host "  GitHub unreachable from this network. Gitee is reachable." -ForegroundColor Yellow
    Write-Host "  ACTION: use Gitee as the remote, or set up a local bare repo as origin (see PLAN\2-远程仓库与GitHub登录.md)." -ForegroundColor Yellow
} else {
    Write-Host "  No external git host is reachable. Use a local bare repo as origin for now." -ForegroundColor Red
}
Write-Host ""
