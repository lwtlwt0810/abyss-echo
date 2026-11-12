# 一键推送仓库到 GitHub（不打印 token，不写入仓库）
# 用法:
#   $env:GITHUB_TOKEN="ghp_xxx"
#   powershell -ExecutionPolicy Bypass -File scripts\push-to-github.ps1 -RepoUrl "https://github.com/<user>/<repo>.git"
param(
  [Parameter(Mandatory = $true)][string]$RepoUrl,
  [string]$Branch = 'main',
  [string]$Message = 'Abyss Echo: game + mobile packaging'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$token = $env:GITHUB_TOKEN
if (-not $token) {
  Write-Host "[!] 未检测到 GITHUB_TOKEN，将以匿名方式推送（私有仓库会失败）。"
}

if (-not (Test-Path (Join-Path $root '.git'))) {
  git init | Out-Null
  git add .
  git commit -m $Message | Out-Null
  git branch -M $Branch
} else {
  git add .
  $dirty = git status --porcelain
  if ($dirty) { git commit -m $Message | Out-Null }
  git branch -M $Branch
}

$remotes = git remote
if ($remotes -contains 'origin') { git remote remove origin }
git remote add origin $RepoUrl

if ($token) {
  $auth = $RepoUrl -replace '^https://', "https://x-access-token:$token@"
  git push $auth "HEAD:$Branch"
} else {
  git push origin "HEAD:$Branch"
}

Write-Host "[ok] 已推送。前往仓库 Actions 页面手动触发 Mobile Build。"
