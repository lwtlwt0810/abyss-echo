# 触屏回归测试：用 CDP 真实触摸事件验证双摇杆、自动开火、无 JS 异常
$ErrorActionPreference = 'Stop'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$tmp = $env:TEMP
$shots = Join-Path $tmp 'abyss_mobile'
New-Item -ItemType Directory -Force -Path $shots | Out-Null
$profile = Join-Path $tmp 'abyss_cdp_mobile'
if (Test-Path $profile) { Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue }

$proc = Start-Process -FilePath $chrome -PassThru -ArgumentList @(
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--hide-scrollbars', '--mute-audio', '--window-size=900,420',
  '--remote-debugging-port=9355', "--user-data-dir=$profile", 'about:blank'
)
Start-Sleep -Milliseconds 1800
$targets = Invoke-RestMethod -Uri 'http://127.0.0.1:9355/json' -TimeoutSec 8
$page = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [System.Threading.CancellationToken]::None).Wait()

$script:msgId = 0
function Send-Cdp($method, $params) {
  $script:msgId++
  $payload = @{ id = $script:msgId; method = $method; params = $params } | ConvertTo-Json -Depth 12 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
  return $script:msgId
}
function Read-Cdp {
  $buf = New-Object byte[] 524288
  $sb = [System.Text.StringBuilder]::new()
  do {
    $r = $ws.ReceiveAsync([System.ArraySegment[byte]]::new($buf), [System.Threading.CancellationToken]::None).Result
    [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $r.Count))
  } while (-not $r.EndOfMessage)
  return $sb.ToString()
}
function Invoke-Cdp($method, $params) {
  $id = Send-Cdp $method $params
  for ($i = 0; $i -lt 900; $i++) {
    $raw = Read-Cdp
    try { $obj = $raw | ConvertFrom-Json } catch { continue }
    if ($obj.id -eq $id) { return $obj }
    if ($obj.method -eq 'Runtime.exceptionThrown') { Write-Output ('EXCEPTION ' + $obj.params.exceptionDetails.text) }
    if ($obj.method -eq 'Log.entryAdded' -and $obj.params.entry.level -eq 'error') { Write-Output ('LOG ' + $obj.params.entry.text) }
  }
  return $null
}
function Eval($expr) {
  $r = Invoke-Cdp 'Runtime.evaluate' @{ expression = $expr; returnByValue = $true }
  if ($r -and $r.result) {
    if ($r.result.exceptionDetails) { return 'JSERR: ' + $r.result.exceptionDetails.text }
    if ($r.result.result) { return $r.result.result.value }
  }
  return $null
}
function Shot($name) {
  $r = Invoke-Cdp 'Page.captureScreenshot' @{ format = 'png' }
  if ($r -and $r.result -and $r.result.data) {
    $p = Join-Path $shots ($name + '.png')
    [System.IO.File]::WriteAllBytes($p, [System.Convert]::FromBase64String($r.result.data))
    Write-Output ('SHOT ' + $p)
  }
}
function Touch($type, $pts) {
  $arr = @()
  foreach ($p in $pts) {
    $arr += @{ x = [double]$p[0]; y = [double]$p[1]; id = [int]$p[2]; radiusX = 6; radiusY = 6; force = 1.0 }
  }
  return (Invoke-Cdp 'Input.dispatchTouchEvent' @{ type = $type; touchPoints = $arr })
}

[void](Invoke-Cdp 'Page.enable' @{})
[void](Invoke-Cdp 'Runtime.enable' @{})
[void](Invoke-Cdp 'Log.enable' @{})
[void](Invoke-Cdp 'Emulation.setTouchEmulationEnabled' @{ enabled = $true; maxTouchPoints = 5 })
[void](Invoke-Cdp 'Emulation.setDeviceMetricsOverride' @{ width = 900; height = 420; deviceScaleFactor = 2; mobile = $true })
[void](Invoke-Cdp 'Page.navigate' @{ url = 'http://localhost:8123/index.html' })
Start-Sleep -Milliseconds 2000

$inject = @'
window.__T = {
  pos(ux, uy) {
    const w = innerWidth, h = innerHeight, b = Math.min(w / 1280, h / 720);
    return { x: (w - 1280 * b) / 2 + ux * b, y: (h - 720 * b) / 2 + uy * b };
  },
  click(ux, uy) {
    const p = this.pos(ux, uy), cv = document.getElementById('game');
    for (const t of ['pointerdown', 'pointerup'])
      cv.dispatchEvent(new PointerEvent(t, { clientX: p.x, clientY: p.y, pointerType: 'touch', pointerId: 7, buttons: t === 'pointerup' ? 0 : 1, bubbles: true, cancelable: true }));
    return 'ok';
  },
  tdown(ux, uy, id) {
    const p = this.pos(ux, uy), cv = document.getElementById('game');
    cv.dispatchEvent(new PointerEvent('pointerdown', { clientX: p.x, clientY: p.y, pointerType: 'touch', pointerId: id, isPrimary: id === 1, buttons: 1, bubbles: true, cancelable: true }));
    return 'tdown' + id;
  },
  tmove(ux, uy, id) {
    const p = this.pos(ux, uy), cv = document.getElementById('game');
    cv.dispatchEvent(new PointerEvent('pointermove', { clientX: p.x, clientY: p.y, pointerType: 'touch', pointerId: id, buttons: 1, bubbles: true, cancelable: true }));
    return 'tmove';
  },
  tup(ux, uy, id) {
    const p = this.pos(ux, uy), cv = document.getElementById('game');
    cv.dispatchEvent(new PointerEvent('pointerup', { clientX: p.x, clientY: p.y, pointerType: 'touch', pointerId: id, buttons: 0, bubbles: true, cancelable: true }));
    return 'tup';
  }
};
'ok'
'@
Write-Output ('INJECT ' + (Eval $inject))

# 进入战斗（跳过标题/选角，避免依赖具体按钮坐标）
Write-Output ('BOOT ' + (Eval 'window.__qa.char(0)'))
Start-Sleep -Milliseconds 900
Write-Output ('STATE ' + (Eval 'window.__abyss.state()'))
Shot '10_playing_touch'

$p0 = Eval 'JSON.stringify(window.__abyss.player())'
Write-Output ('P0 ' + $p0)

# 1) 左半屏按住并拖动 = 移动摇杆
Touch 'touchStart' @(@(180, 320, 1))
Start-Sleep -Milliseconds 120
for ($k = 1; $k -le 8; $k++) {
  Touch 'touchMove' @(@((180 + $k * 10), 320, 1))
  Start-Sleep -Milliseconds 90
}
Start-Sleep -Milliseconds 350
$p1 = Eval 'JSON.stringify(window.__abyss.player())'
Write-Output ('P1 ' + $p1)
Touch 'touchEnd' @()
Start-Sleep -Milliseconds 200

# 2) 右半屏按住 = 瞄准并自动开火
$b0 = Eval 'JSON.stringify(window.__abyss.run())'
Touch 'touchStart' @(@(700, 150, 2))
Start-Sleep -Milliseconds 150
for ($k = 1; $k -le 6; $k++) {
  Touch 'touchMove' @(@((700 - $k * 12), (150 + $k * 8), 2))
  Start-Sleep -Milliseconds 120
}
$b1 = Eval 'JSON.stringify(window.__abyss.run())'
Write-Output ('FIRE_BEFORE ' + $b0)
Write-Output ('FIRE_AFTER  ' + $b1)
Shot '11_touch_fire'

# 3) 双指同时操作
Touch 'touchStart' @(@(160, 300, 11), @(720, 120, 12))
Start-Sleep -Milliseconds 400
Touch 'touchMove' @(@(200, 300, 11), @(680, 160, 12))
Start-Sleep -Milliseconds 500
$p2 = Eval 'JSON.stringify(window.__abyss.player())'
Write-Output ('P2_DUAL ' + $p2)
Touch 'touchEnd' @()
Start-Sleep -Milliseconds 300

# 4) 页面内 PointerEvent(pointerType=touch) 复核左摇杆
$pa = Eval 'JSON.stringify(window.__abyss.player())'
[void](Eval 'window.__T.tdown(260, 520, 21)')
Start-Sleep -Milliseconds 100
for ($k = 1; $k -le 10; $k++) {
  [void](Eval ('window.__T.tmove(' + (260 + $k * 12) + ', 520, 21)'))
  Start-Sleep -Milliseconds 70
}
Start-Sleep -Milliseconds 300
$pb = Eval 'JSON.stringify(window.__abyss.player())'
Write-Output ('MOVE_INPAGE_BEFORE ' + $pa)
Write-Output ('MOVE_INPAGE_AFTER  ' + $pb)
[void](Eval 'window.__T.tup(380, 520, 21)')
Shot '13_move_inpage'

Write-Output ('FPS ' + (Eval 'Math.round((window.__abyss.run()||{}).fps||0)'))
Write-Output ('ERR [' + (Eval "document.getElementById('err').textContent") + ']')
Write-Output ('STATE_END ' + (Eval 'window.__abyss.state()'))
Shot '12_touch_end'
Write-Output 'DONE'

$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'bye', [System.Threading.CancellationToken]::None).Wait()
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
