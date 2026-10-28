#!/bin/sh
# Installs pcbkit (https://github.com/pcbkit-io/cli) on macOS or Linux:
#
#   curl -fsSL https://pcbkit.io/install.sh | sh
#
# It downloads the release archive for this system from GitHub Releases, checks its SHA-256
# against the release's SHA256SUMS and installs PREFIX/bin/pcbkit and PREFIX/share/pcbkit/.
# Run it again to update.
#
#   PCBKIT_VERSION=2026.10.28   that version (default: the latest release)
#   PCBKIT_PREFIX=/usr/local    where (default: ~/.local)
set -eu

repo=https://github.com/pcbkit-io/cli
prefix=${PCBKIT_PREFIX:-$HOME/.local}
version=${PCBKIT_VERSION:-}

say() { printf 'pcbkit: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

case "$(uname -s)" in
  Darwin) os=apple-darwin ;;
  Linux) os=unknown-linux-gnu ;;
  MINGW* | MSYS* | CYGWIN*) die "on Windows run in PowerShell: irm https://pcbkit.io/install.ps1 | iex" ;;
  *) die "no release for $(uname -s); see $repo" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=x86_64 ;;
  arm64 | aarch64) arch=aarch64 ;;
  *) die "no release for $(uname -m); see $repo" ;;
esac
# A shell under Rosetta on Apple silicon: the native build.
if [ "$os" = apple-darwin ] && [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
  arch=aarch64
fi
if [ "$os" = unknown-linux-gnu ]; then
  glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
  [ -n "$glibc" ] || die "the Linux release needs glibc 2.35 or newer (this system has none: musl?); see $repo"
  major=${glibc%%.*} minor=${glibc#*.}; minor=${minor%%.*}
  [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 35 ]; } || die "the Linux release needs glibc 2.35 or newer (this system has $glibc)"
fi
target=$arch-$os
asset=pcbkit-$target.tar.gz

if [ -n "$version" ]; then
  base=$repo/releases/download/v${version#v}
else
  base=$repo/releases/latest/download
fi

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  die "needs curl or wget"
fi
if command -v sha256sum >/dev/null 2>&1; then
  sha() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  die "needs sha256sum or shasum"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
say "downloading $asset${version:+ ($version)}"
fetch "$base/$asset" "$tmp/$asset" || die "could not download $base/$asset"
fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || die "could not download $base/SHA256SUMS"
want=$(awk -v f="$asset" '$2 == f || $2 == "*"f {print $1}' "$tmp/SHA256SUMS")
got=$(sha "$tmp/$asset")
[ -n "$want" ] || die "SHA256SUMS does not list $asset"
[ "$want" = "$got" ] || die "checksum mismatch for $asset (expected $want, got $got): not installed"

mkdir -p "$tmp/x"
tar -xzf "$tmp/$asset" -C "$tmp/x"
[ -x "$tmp/x/bin/pcbkit" ] || die "the archive has no bin/pcbkit"
mkdir -p "$prefix/bin" "$prefix/share" || die "cannot write to $prefix (PCBKIT_PREFIX=… for another place)"
rm -rf "$prefix/share/pcbkit"
cp -R "$tmp/x/share/pcbkit" "$prefix/share/pcbkit"
# A new file, then a rename: a running pcbkit keeps its own.
cp "$tmp/x/bin/pcbkit" "$prefix/bin/.pcbkit.new"
chmod 755 "$prefix/bin/.pcbkit.new"
mv -f "$prefix/bin/.pcbkit.new" "$prefix/bin/pcbkit"

installed=$("$prefix/bin/pcbkit" --version 2>/dev/null || true)
say "installed ${installed:-pcbkit} at $prefix/bin/pcbkit"
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) say "add it to your PATH: export PATH=\"$prefix/bin:\$PATH\" (in ~/.zshrc, ~/.bashrc or ~/.profile)" ;;
esac
say "start: cd your-kicad-project && pcbkit init && pcbkit check   (docs: $repo)"
