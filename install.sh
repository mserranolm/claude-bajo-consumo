#!/usr/bin/env bash
# Instalación completa desde zip o clon. Mismas opciones que instalar.sh (--dry-run, --idioma, ...).
set -euo pipefail
exec bash "$(cd "$(dirname "$0")" && pwd)/plugins/bajo-consumo/skills/ahorro-tokens/scripts/instalar.sh" "$@"
