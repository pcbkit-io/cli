# Installs pcbkit (https://github.com/pcbkit-io/cli) on Windows:
#
#   irm https://pcbkit.io/install.ps1 | iex
#
# It downloads the release archive from GitHub Releases, checks its SHA-256 against the release's
# SHA256SUMS, installs it into %LOCALAPPDATA%\Programs\pcbkit (bin\pcbkit.exe, share\pcbkit\)
# and adds bin to the user's PATH. Run it again to update.
#
#   $env:PCBKIT_VERSION = "2026.10.28"   that version (default: the latest release)
#   $env:PCBKIT_PREFIX = "D:\tools\pcbkit"   where
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'https://github.com/pcbkit-io/cli'
$prefix = if ($env:PCBKIT_PREFIX) { $env:PCBKIT_PREFIX } else { Join-Path $env:LOCALAPPDATA 'Programs\pcbkit' }
$version = $env:PCBKIT_VERSION

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
if ($arch -ne 'X64' -and $arch -ne 'Arm64') { throw "pcbkit: no release for $arch; see $repo" }
# Windows on Arm runs the x86_64 build.
$asset = 'pcbkit-x86_64-pc-windows-msvc.zip'
$base = if ($version) { "$repo/releases/download/v$($version.TrimStart('v'))" } else { "$repo/releases/latest/download" }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pcbkit-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "pcbkit: downloading $asset"
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile (Join-Path $tmp $asset)
  Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $tmp 'SHA256SUMS')
  $want = (Get-Content (Join-Path $tmp 'SHA256SUMS') | Where-Object { ($_ -split '\s+')[1] -eq $asset } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
  if (-not $want) { throw "pcbkit: SHA256SUMS does not list $asset" }
  $got = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $asset)).Hash.ToLower()
  if ($want.ToLower() -ne $got) { throw "pcbkit: checksum mismatch for $asset (expected $want, got $got): not installed" }

  $x = Join-Path $tmp 'x'
  Expand-Archive -Path (Join-Path $tmp $asset) -DestinationPath $x
  New-Item -ItemType Directory -Force -Path (Join-Path $prefix 'bin'), (Join-Path $prefix 'share') | Out-Null
  $share = Join-Path $prefix 'share\pcbkit'
  if (Test-Path $share) { Remove-Item -Recurse -Force $share }
  Copy-Item -Recurse (Join-Path $x 'share\pcbkit') $share
  $exe = Join-Path $prefix 'bin\pcbkit.exe'
  # A running pcbkit.exe cannot be overwritten, but it can be renamed away.
  if (Test-Path $exe) { Move-Item -Force $exe "$exe.old" -ErrorAction SilentlyContinue }
  Copy-Item (Join-Path $x 'bin\pcbkit.exe') $exe
  Remove-Item -Force "$exe.old" -ErrorAction SilentlyContinue
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

$bin = Join-Path $prefix 'bin'
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($path -split ';') -contains $bin)) {
  [Environment]::SetEnvironmentVariable('Path', ($(if ($path) { "$path;" } else { '' }) + $bin), 'User')
  $env:Path = "$env:Path;$bin"
  Write-Host "pcbkit: added $bin to your PATH (new terminals see it)"
}
$v = & $exe --version
Write-Host "pcbkit: installed $v at $exe"
Write-Host "pcbkit: start: cd your-kicad-project; pcbkit init; pcbkit check   (docs: $repo)"
