<#
.SYNOPSIS
  무선 디버깅(adb wireless) 연결이 안 잡히거나 오래 걸릴 때 쓰는 복구 스크립트.

.DESCRIPTION
  adb-tls-connect mDNS 서비스에는 폰이 무선 디버깅을 껐다 켤 때마다 새 포트가 등록되는데,
  이전 세션의 죽은 포트가 같이 남아있어서 Android Studio가 죽은 포트를 먼저 시도하다
  타임아웃(약 1분)되는 경우가 있다. 기종에 따라(특히 One UI) mDNS 광고 자체가 죽어서
  아예 안 잡히는 경우도 있다. 이 스크립트는:
    1) adb 서버를 재시작하고
    2) -Target으로 IP:포트를 직접 주면 mDNS 없이 바로 그 주소로 connect하고
       (폰의 "무선 디버깅" 화면에 표시된 IP 주소 및 포트를 그대로 쓰면 됨)
    3) -Target이 없으면 mDNS로 광고 중인 모든 adb-tls-connect 후보를 조회해
       각 후보에 순서대로 connect를 시도, 살아있는 포트를 찾아 자동 연결한다.

.PARAMETER Target
  폰의 "무선 디버깅" 화면에 표시된 IP:포트 (예: 192.168.0.2:40149).
  mDNS가 안 잡힐 때 이 값을 직접 넘기면 탐색을 건너뛰고 바로 연결을 시도한다.

.USAGE
  powershell -ExecutionPolicy Bypass -File .\scripts\adbfix.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\adbfix.ps1 -Target 192.168.0.2:40149
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}:\d{1,5}$')]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

function Resolve-Adb {
    $candidate = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $candidate) { return $candidate }
    $onPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw "adb.exe를 찾을 수 없습니다. Android SDK platform-tools 설치 경로를 확인하세요."
}

$adb = Resolve-Adb
Write-Host "[adbfix] adb: $adb" -ForegroundColor DarkGray

Write-Host "[adbfix] adb 서버 재시작 중..." -ForegroundColor Cyan
& $adb kill-server 2>$null
& $adb start-server | Out-Null

if ($Target) {
    Write-Host "[adbfix] mDNS 건너뛰고 $Target 로 바로 연결 시도..." -ForegroundColor Cyan
    $result = & $adb connect $Target 2>&1
    Write-Host "  $result"
    if ($result -notmatch 'connected to') {
        Write-Host "[adbfix] 연결 실패. 폰의 무선 디버깅 화면에 뜬 IP:포트가 맞는지, 토글을 껐다 켰는지 확인하세요." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "[adbfix] 기기 목록:" -ForegroundColor Green
    & $adb devices -l
    exit 0
}

Write-Host "[adbfix] mDNS로 무선 디버깅 서비스 탐색 중..." -ForegroundColor Cyan
$raw = & $adb mdns services

# 형식 예: "adb-R3CX20E94NF-UOwb7s (2)`t_adb-tls-connect._tcp`t192.168.0.2:33735"
$candidates = @()
foreach ($line in $raw) {
    if ($line -match '_adb-tls-connect\._tcp\s+(\S+):(\d+)') {
        $candidates += [pscustomobject]@{ Ip = $Matches[1]; Port = $Matches[2] }
    }
}

if ($candidates.Count -eq 0) {
    Write-Host "[adbfix] 무선 디버깅 서비스가 안 잡힙니다." -ForegroundColor Yellow
    Write-Host "  → 폰에서 설정 > 개발자 옵션 > 무선 디버깅이 켜져 있는지, 같은 Wi-Fi인지 확인하세요."
    exit 1
}

Write-Host "[adbfix] 후보 $($candidates.Count)개 발견, 연결 시도..." -ForegroundColor Cyan

$connected = $false
foreach ($c in $candidates) {
    $target = "$($c.Ip):$($c.Port)"
    Write-Host "  - $target 시도 중..." -NoNewline
    $result = & $adb connect $target 2>&1
    if ($result -match 'connected to') {
        Write-Host " 성공" -ForegroundColor Green
        $connected = $true
        break
    } else {
        Write-Host " 실패 (죽은 레코드로 추정)" -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($connected) {
    Write-Host "[adbfix] 연결 완료. 기기 목록:" -ForegroundColor Green
} else {
    Write-Host "[adbfix] 살아있는 포트를 찾지 못했습니다. 폰에서 무선 디버깅을 껐다 켜본 뒤 다시 시도하세요." -ForegroundColor Yellow
}
& $adb devices -l
