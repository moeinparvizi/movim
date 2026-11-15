param([switch]$MacOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent $repo
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { $node = (Get-ChildItem "$workspace/.tools/node-v*-win-x64/node.exe" | Select-Object -First 1).FullName }
if (-not $node) { throw 'Node.js is required.' }
if (-not (Test-Path "$workspace/movim-macOS.zip")) { throw 'Build the standard installers first.' }
& $node "$PSScriptRoot/manifest.cjs"
if ($LASTEXITCODE -ne 0) { throw 'AI manifest failed.' }
$manifest = Get-Content "$PSScriptRoot/dist/ai-release.json" -Raw | ConvertFrom-Json
$stage = Join-Path $PSScriptRoot ('dist/stage-' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath "$workspace/movim-macOS.zip" -DestinationPath $stage
$package = Join-Path $stage 'movim-macOS'
$base = Get-Content "$package/config/release.json" -Raw | ConvertFrom-Json
if ($base.version -ne $manifest.version) { throw 'Base and AI package versions differ; rebuild the base.' }
$aiTarget = Join-Path $package 'config/ai'
New-Item -ItemType Directory -Force "$aiTarget/runtime" | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/lua" -Destination $aiTarget -Recurse
Copy-Item -LiteralPath "$PSScriptRoot/README.md" -Destination $aiTarget
Copy-Item -LiteralPath "$PSScriptRoot/runtime/package.json","$PSScriptRoot/runtime/package-lock.json" -Destination "$aiTarget/runtime"
Copy-Item -LiteralPath "$PSScriptRoot/dist/ai-release.json" -Destination $aiTarget
Copy-Item -LiteralPath "$PSScriptRoot/installer/Install.command" -Destination "$package/Install.command" -Force
& $node "$repo/installer/verify-package.cjs" "$package/config"
if ($LASTEXITCODE -ne 0) { throw 'Base config mismatch.' }
& $node "$PSScriptRoot/verify.cjs" $aiTarget
if ($LASTEXITCODE -ne 0) { throw 'AI config mismatch.' }
# Use the shared ZIP writer so macOS preserves executable permissions.
& $node "$PSScriptRoot/zip.cjs" $package "$PSScriptRoot/dist/movim-AI-macOS.zip"
if ($LASTEXITCODE -ne 0) { throw 'AI macOS archive failed.' }
if (-not $MacOnly) {
  $piPackage = "$PSScriptRoot/runtime/node_modules/@mariozechner/pi-coding-agent/package.json"
  if (-not (Test-Path $piPackage) -or (Get-Content $piPackage -Raw | ConvertFrom-Json).version -ne $manifest.pi) { throw 'Run npm ci --ignore-scripts inside ai/runtime first.' }
  & tar.exe -cf "$PSScriptRoot/dist/pi-runtime.tar" -C "$PSScriptRoot/runtime" node_modules
  if ($LASTEXITCODE -ne 0) { throw 'Pi runtime archive failed.' }
  $compiler = "$workspace/.tools/innosetup/ISCC.exe"
  if (-not (Test-Path $compiler)) { throw 'Inno Setup compiler missing.' }
  & $compiler "/DWorkspace=$workspace" "/DProductVersion=$($manifest.version)" '/DAiBuild' "$repo/installer/setup.iss"
  if ($LASTEXITCODE -ne 0) { throw 'AI Windows installer failed.' }
}
Get-ChildItem "$PSScriptRoot/dist/movim-AI-*" -File | Get-FileHash -Algorithm SHA256 | ForEach-Object { $_.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_.Path) } | Set-Content -Encoding ASCII "$PSScriptRoot/dist/SHA256SUMS"
Write-Host "AI packages ready in $PSScriptRoot/dist"
