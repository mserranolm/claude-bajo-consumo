#!/usr/bin/env bash
# Genera dist/claude-bajo-consumo.zip desde lo commiteado (git archive: nada sin versionar se cuela).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
git archive --format=zip --prefix=claude-bajo-consumo/ -o dist/claude-bajo-consumo.zip HEAD
echo "dist/claude-bajo-consumo.zip"
