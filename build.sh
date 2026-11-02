#!/usr/bin/env bash
# Builds LoLBypass.exe (.NET Framework 4.8) and the NSIS installer. Works on Linux or Windows (Git Bash).
# Needs: .NET SDK 8+ (dotnet) and NSIS 3 (makensis).
set -euo pipefail
VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build"
rm -rf "$OUT"
dotnet build "$ROOT/src/LoLBypass/LoLBypass.csproj" -c Release -o "$OUT" -p:Version="$VERSION"
cd "$ROOT/installer"
makensis -V2 -DVERSION="$VERSION" -DBUILD_DIR="$OUT" -DPAYLOAD_DIR="$ROOT/payload" LoLBypass.nsi
echo "Built: installer/LoLBypass-Setup-$VERSION.exe"
