param(
  [switch]$MacOnly,
  [switch]$WindowsOnly
)
$ErrorActionPreference = 'Stop'
if ($MacOnly -and $WindowsOnly) { throw 'Select at most one of -MacOnly and -WindowsOnly.' }
$versionSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../lua/config/version.lua') -Raw
if ($versionSource -notmatch "return ['`"](\d+\.\d+\.\d+)['`"]") { throw 'Invalid movim release version.' }
$version = $Matches[1]
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\')
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) { $nodePath = $node.Source } else {
  $nodePath = (Get-ChildItem -Path (Join-Path $workspace '.tools/node-v*-win-x64/node.exe') | Select-Object -First 1).FullName
}
if (-not $nodePath) { throw 'Node.js is required to generate the release manifest.' }
& $nodePath (Join-Path $PSScriptRoot 'manifest.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Could not generate the release manifest.' }

function Add-PackageFile($archive, [string]$source, [string]$name, [bool]$executable = $false) {
  $entry = $archive.CreateEntry($name.Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
  # ZIP Unix permissions: regular file, 0755 for the Finder launcher, 0644 otherwise.
  $mode = if ($executable) { [uint32]2179792896 } else { [uint32]2175008768 }
  $entry.ExternalAttributes = [BitConverter]::ToInt32([BitConverter]::GetBytes($mode), 0)
  $inputStream = [IO.File]::OpenRead($source)
  try {
    $outputStream = $entry.Open()
    try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
  } finally { $inputStream.Dispose() }
}

if (-not $WindowsOnly) {
  Add-Type -AssemblyName System.IO.Compression
  $output = Join-Path $workspace 'movim-macOS.zip'
  $temporary = "$output.tmp"
  if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
  $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew)
  try {
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
      $mac = Join-Path $PSScriptRoot 'macos'
      Add-PackageFile $zip (Join-Path $mac 'Install.command') 'movim-macOS/Install.command' $true
      Add-PackageFile $zip (Join-Path $mac 'README.txt') 'movim-macOS/README.txt'
      $config = Join-Path $workspace 'neovim'
      foreach ($file in @('init.lua', 'lazy-lock.json', 'README.md', 'LICENSE', 'CHANGELOG.md', 'release.json', 'site/docs-en/README.md')) {
        $path = Join-Path $config $file
        if (Test-Path -LiteralPath $path -PathType Leaf) { Add-PackageFile $zip $path "movim-macOS/config/$file" }
      }
      foreach ($directory in @('lua', 'colors', 'keymap', 'docs', 'fonts')) {
        $base = Join-Path $config $directory
        if (Test-Path -LiteralPath $base -PathType Container) {
          Get-ChildItem -LiteralPath $base -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($config.Length + 1).Replace('\', '/')
            Add-PackageFile $zip $_.FullName "movim-macOS/config/$relative"
          }
        }
      }
    } finally { $zip.Dispose() }
  } finally { $stream.Dispose() }
  # .NET on Windows marks ZIP entries as DOS; mark them Unix so macOS preserves chmod.
  $bytes = [IO.File]::ReadAllBytes($temporary)
  $eocd = -1
  for ($i = $bytes.Length - 22; $i -ge [Math]::Max(0, $bytes.Length - 65557); $i--) {
    if ([BitConverter]::ToUInt32($bytes, $i) -eq 0x06054b50 -and
        $i + 22 + [BitConverter]::ToUInt16($bytes, $i + 20) -eq $bytes.Length) { $eocd = $i; break }
  }
  if ($eocd -lt 0) { throw 'ZIP central directory not found.' }
  $entryCount = [BitConverter]::ToUInt16($bytes, $eocd + 10)
  $offset = [int][BitConverter]::ToUInt32($bytes, $eocd + 16)
  for ($i = 0; $i -lt $entryCount; $i++) {
    if ([BitConverter]::ToUInt32($bytes, $offset) -ne 0x02014b50) { throw 'Invalid ZIP central directory.' }
    $bytes[$offset + 5] = 3
    $offset += 46 + [BitConverter]::ToUInt16($bytes, $offset + 28) +
      [BitConverter]::ToUInt16($bytes, $offset + 30) + [BitConverter]::ToUInt16($bytes, $offset + 32)
  }
  [IO.File]::WriteAllBytes($temporary, $bytes)
  Move-Item -LiteralPath $temporary -Destination $output -Force
  Write-Host "Created $output"
}

if (-not $MacOnly) {
  $compiler = Join-Path $workspace '.tools/innosetup/ISCC.exe'
  if (-not (Test-Path -LiteralPath $compiler)) { throw "Inno Setup compiler missing: $compiler" }
  $mapping = & subst.exe
  $existing = $mapping | Where-Object { $_ -match '^Z:\\: => ' } | Select-Object -First 1
  $createdMapping = $false
  if ($existing) {
    $target = ($existing -replace '^Z:\\: => ', '').TrimEnd('\')
    if (-not [string]::Equals($target, $workspace, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Z: already points to $target. The Windows installer requires it to point to $workspace."
    }
  } else {
    & subst.exe Z: $workspace
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the temporary Z: mapping.' }
    $createdMapping = $true
  }
  try {
    & $compiler "/DProductVersion=$version" 'Z:\neovim\installer\setup.iss'
    if ($LASTEXITCODE -ne 0) { throw "Windows installer build failed ($LASTEXITCODE)." }
    Write-Host "Created $(Join-Path $workspace 'movim-Setup.exe')"
  } finally {
    if ($createdMapping) { & subst.exe Z: /D | Out-Null }
  }
}
