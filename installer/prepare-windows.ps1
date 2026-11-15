# Runtime seed is immutable; configuration and plugin locks always come from this checkout.
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$seed = Join-Path $workspace '.release-seed'
New-Item -ItemType Directory -Force $seed | Out-Null
$installer = Join-Path $seed 'runtime.exe'
Invoke-WebRequest 'https://github.com/moeinparvizi/movim/releases/download/v1.0.0/movim-Setup.exe' -OutFile $installer
$destination = Join-Path $seed 'installed'
$process = Start-Process -FilePath $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOICONS', '/TASKS=""', "/DIR=$destination") -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Runtime seed extraction failed: $($process.ExitCode)" }
foreach ($directory in @('.tools', '.isolated')) {
  Copy-Item -LiteralPath (Join-Path $destination $directory) -Destination $workspace -Recurse -Force
}
# Repack the relocatable language tools; no user's state or saved theme is shipped.
Push-Location $workspace
try {
  & tar.exe -cf '.tools/installer-runtime.tar' '.isolated/runtime' '.isolated/data/nvim-data/mason'
  if ($LASTEXITCODE -ne 0) { throw 'Could not package language tools.' }
} finally { Pop-Location }
$compiler = Get-ChildItem 'C:/Program Files (x86)/Inno Setup*/ISCC.exe' | Select-Object -First 1
if (-not $compiler) { throw 'Install Inno Setup before building the Windows installer.' }
New-Item -ItemType Directory -Force (Join-Path $workspace '.tools/innosetup') | Out-Null
Copy-Item (Join-Path $compiler.DirectoryName '*') (Join-Path $workspace '.tools/innosetup') -Recurse -Force
# Resolve repositories from the actual lazy spec, including renamed plugin directories.
$env:MOVIM_PLUGIN_EXPORT = Join-Path $seed 'plugins.json'
& (Join-Path $PSScriptRoot '../start-webstorm.ps1') --headless -l (Join-Path $PSScriptRoot '../tests/export-plugins.lua')
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve plugin repositories.' }
$plugins = Get-Content $env:MOVIM_PLUGIN_EXPORT -Raw | ConvertFrom-Json
$currentLock = Get-Content (Join-Path $PSScriptRoot '../lazy-lock.json') -Raw | ConvertFrom-Json
$seedLock = Get-Content (Join-Path $destination 'neovim/lazy-lock.json') -Raw | ConvertFrom-Json
foreach ($entry in $currentLock.PSObject.Properties) {
  $name = $entry.Name
  if ($seedLock.$name.commit -eq $entry.Value.commit) { continue }
  $url = $plugins.$name.url
  if ($url -notmatch '^https://github.com/([\w.-]+/[\w.-]+?)(?:\.git)?$') { throw "Unsupported plugin URL: $url" }
  $repository = $Matches[1]
  $archive = Join-Path $seed "$name.tar.gz"
  Invoke-WebRequest "https://api.github.com/repos/$repository/tarball/$($entry.Value.commit)" -OutFile $archive
  $target = Join-Path $workspace ".isolated/data/nvim-data/lazy/$name"
  # Every target is constrained to this disposable build workspace.
  if (-not ([IO.Path]::GetFullPath($target)).StartsWith([IO.Path]::GetFullPath((Join-Path $workspace '.isolated/data/nvim-data/lazy/')))) { throw 'Invalid plugin target.' }
  if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  New-Item -ItemType Directory -Force $target | Out-Null
  & tar.exe -xzf $archive --strip-components=1 -C $target
  if ($LASTEXITCODE -ne 0) { throw "Could not extract $name" }
}
