# Launch the workspace-local installation without modifying the user's Neovim.
$workspace = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $workspace '.tools'
$state = Join-Path $workspace '.isolated'
$nvim = Join-Path $tools 'nvim-win64\bin\nvim.exe'
$node = Get-ChildItem -LiteralPath $tools -Directory -Filter 'node-v*-win-x64' | Select-Object -First 1
if (!(Test-Path -LiteralPath $nvim) -or !$node) { throw 'Portable Neovim or Node.js is missing in the workspace .tools directory.' }
$env:LOCALAPPDATA = $state
$env:XDG_DATA_HOME = Join-Path $state 'data'
$env:XDG_STATE_HOME = Join-Path $state 'state'
$env:XDG_CACHE_HOME = Join-Path $state 'cache'
$git = 'C:\Program Files\Git\cmd'
$bin = Join-Path $state 'runtime\node_modules\.bin'
$lazyGitBin = Join-Path $tools 'lazygit'
$bundledBin = Join-Path $tools 'bin'
# Resolve GapGPT's bundled ripgrep from the original profile, when available.
$gapBin = Join-Path $env:USERPROFILE 'AppData\Local\Programs\GapGPT\resources\bin'
$env:PATH = "$($node.FullName);$bin;$git;$lazyGitBin;$bundledBin;$gapBin;$env:PATH"
$zigNpm = Join-Path $tools 'compiler\node_modules\@ryoppippi\zig-win32-x64'
if (Test-Path (Join-Path $zigNpm 'zig.exe')) { $env:PATH = "$zigNpm;$env:PATH" }
$zig = Get-ChildItem -LiteralPath $tools -Directory -Filter 'zig-*-windows-*' | Select-Object -First 1
if ($zig) { $env:PATH = "$($zig.FullName);$env:PATH" }
$forwardArgs = @($args)
if ($forwardArgs.Count -gt 0 -and (Test-Path -LiteralPath $forwardArgs[0] -PathType Container)) {
  Set-Location -LiteralPath $forwardArgs[0]
  $forwardArgs = @($forwardArgs | Select-Object -Skip 1)
}
$runtime = $PSScriptRoot.Replace('\','/')
& $nvim --cmd "set rtp^=$runtime" -u (Join-Path $PSScriptRoot 'init.lua') @forwardArgs
exit $LASTEXITCODE
