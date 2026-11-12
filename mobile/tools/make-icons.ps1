# 程序化生成 Android / iOS 图标与启动图（System.Drawing 矢量绘制，不引入任何外部素材）
# 用法: powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
param([string]$OutRoot = (Join-Path $PSScriptRoot '..\resources'))

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

function C([int]$a, [int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

function Draw-Bg($g, [int]$size) {
  $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C 255 34 26 78), (C 255 5 6 10), 300.0)
  $g.FillRectangle($bg, $rect)
  $bg.Dispose()
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $rr = [double]$size * 0.80
  $p.AddEllipse([single]($size / 2 - $rr), [single]($size / 2 - $rr), [single]($rr * 2), [single]($rr * 2))
  $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p)
  $pg.CenterColor = (C 80 58 58 152)
  $pg.SurroundColors = @((C 0 0 0 0))
  $g.FillPath($pg, $p)
  $pg.Dispose(); $p.Dispose()
}

function Draw-Mark($g, [int]$size, [double]$scale) {
  $unit = $size * 0.5 * $scale
  $cx = [single]($size / 2); $cy = [single]($size / 2)

  # 回响光晕
  $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
  $gr = $unit * 0.92
  $gp.AddEllipse([single]($cx - $gr), [single]($cy - $gr), [single]($gr * 2), [single]($gr * 2))
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp)
  $pgb.CenterColor = (C 70 70 140 255)
  $pgb.SurroundColors = @((C 0 70 140 255))
  $g.FillPath($pgb, $gp)
  $pgb.Dispose(); $gp.Dispose()

  # 三道回响弧（顶部缺口，象征"回响"）
  $rings = @(
    @(0.80, 0.040, 170, 112, 85, 255),
    @(0.61, 0.048, 235, 79, 216, 255),
    @(0.42, 0.054, 255, 180, 245, 255)
  )
  foreach ($r in $rings) {
    $rad = $unit * $r[0]
    $pen = New-Object System.Drawing.Pen((C ([int]$r[2]) ([int]$r[3]) ([int]$r[4]) ([int]$r[5])), [single]($unit * $r[1]))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($pen, [single]($cx - $rad), [single]($cy - $rad), [single]($rad * 2), [single]($rad * 2), -60, 300)
    $pen.Dispose()
  }

  # 核心：下指菱形
  $u = $unit * 0.30
  $rect = New-Object System.Drawing.RectangleF([single]($cx - $u), [single]($cy - $u), [single]($u * 2), [single]($u * 2))
  $dia = New-Object System.Drawing.Drawing2D.GraphicsPath
  $dia.AddPolygon([System.Drawing.PointF[]]@(
      (New-Object System.Drawing.PointF($cx, ($cy - $u))),
      (New-Object System.Drawing.PointF(($cx + $u), $cy)),
      (New-Object System.Drawing.PointF($cx, ($cy + $u))),
      (New-Object System.Drawing.PointF(($cx - $u), $cy))
    ))
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C 255 255 255 255), (C 255 120 200 255), 90.0)
  $g.FillPath($br, $dia)
  $br.Dispose(); $dia.Dispose()

  # 核心暗槽
  $s = $unit * 0.10
  $slot = New-Object System.Drawing.Drawing2D.GraphicsPath
  $slot.AddEllipse([single]($cx - $s), [single]($cy - $s * 0.7), [single]($s * 2), [single]($s * 1.4))
  $sb = New-Object System.Drawing.SolidBrush((C 210 20 24 60))
  $g.FillPath($sb, $slot)
  $sb.Dispose(); $slot.Dispose()
}

function Save-Icon([string]$file, [int]$size, [bool]$withBg, [double]$scale, [bool]$round) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.Clear([System.Drawing.Color]::Transparent)
  if ($round) {
    $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse(0, 0, $size, $size)
    $g.SetClip($clip)
  }
  if ($withBg) { Draw-Bg $g $size }
  Draw-Mark $g $size $scale
  $g.Dispose()
  $dir = Split-Path $file -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host ("  " + $file.Replace($OutRoot, '.'))
}

Write-Host '[icons] 生成基础资源…'
Save-Icon (Join-Path $OutRoot 'icon.png') 1024 $true 0.86 $false
Save-Icon (Join-Path $OutRoot 'icon-foreground.png') 1024 $false 0.58 $false
Save-Icon (Join-Path $OutRoot 'icon-background.png') 1024 $true 0.0001 $false
Save-Icon (Join-Path $OutRoot 'splash.png') 2048 $true 0.40 $false

Write-Host '[icons] 生成 Android 各密度图标…'
$dens = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($k in $dens.Keys) {
  $sz = $dens[$k]
  $d = Join-Path $OutRoot "android\mipmap-$k"
  Save-Icon (Join-Path $d 'ic_launcher.png') $sz $true 0.86 $false
  Save-Icon (Join-Path $d 'ic_launcher_round.png') $sz $true 0.86 $true
  $fg = [int]($sz * 108 / 48)
  Save-Icon (Join-Path $d 'ic_launcher_foreground.png') $fg $false 0.52 $false
}
$drawable = Join-Path $OutRoot 'android\drawable'
New-Item -ItemType Directory -Force -Path $drawable | Out-Null
Copy-Item (Join-Path $OutRoot 'splash.png') (Join-Path $drawable 'splash.png') -Force

Write-Host '[icons] 生成 iOS 资源…'
$iosApp = Join-Path $PSScriptRoot '..\ios\App\Assets.xcassets'
Save-Icon (Join-Path $iosApp 'AppIcon.appiconset\AppIcon.png') 1024 $true 0.86 $false
Save-Icon (Join-Path $iosApp 'LaunchLogo.imageset\LaunchLogo.png') 512 $false 0.80 $false
$iosOut = Join-Path $OutRoot 'ios'
New-Item -ItemType Directory -Force -Path $iosOut | Out-Null
Copy-Item (Join-Path $iosApp 'AppIcon.appiconset\AppIcon.png') (Join-Path $iosOut 'AppIcon-1024.png') -Force

Write-Host '[icons] 完成'
