#!/usr/bin/env bash
# Instala la configuración de bajo consumo de tokens. Idempotente: lo que ya está, se salta.
# Uso: instalar.sh [--dry-run] [--sin-plugins] [--sin-ajustes] [--idioma <Idioma>]
set -euo pipefail

DRY=0; PLUGINS=1; AJUSTES=1; IDIOMA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --sin-plugins) PLUGINS=0; shift ;;
    --sin-ajustes) AJUSTES=0; shift ;;
    --idioma) IDIOMA="${2:?falta el idioma}"; shift 2 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

AQUI="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$AQUI")"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
INSTALADOS="$CLAUDE_DIR/plugins/installed_plugins.json"
MARKETS="$CLAUDE_DIR/plugins/known_marketplaces.json"

# marketplace|repo|plugin
PAQUETES=(
  "caveman|JuliusBrussee/caveman|caveman@caveman"
  "context-mode|mksglu/context-mode|context-mode@context-mode"
  "haiku-shunt|mserranolm/haiku-shunt|haiku-shunt@haiku-shunt"
)

need=(jq); [ "$PLUGINS" = 1 ] && need+=(claude node)
for bin in "${need[@]}"; do
  command -v "$bin" >/dev/null || { echo "Falta '$bin' en el PATH" >&2; exit 1; }
done

run() {
  if [ "$DRY" = 1 ]; then echo "  [dry-run] $*"; else echo "  > $*"; "$@"; fi
}
instalado() { [ -f "$INSTALADOS" ] && jq -e --arg k "$1" '.plugins | has($k)' "$INSTALADOS" >/dev/null; }

if [ "$PLUGINS" = 1 ]; then
  echo "== Plugins"
  for p in "${PAQUETES[@]}"; do
    IFS='|' read -r mk repo plugin <<<"$p"
    if [ -f "$MARKETS" ] && jq -e --arg k "$mk" 'has($k)' "$MARKETS" >/dev/null; then
      echo "  marketplace $mk: ya está"
    else
      run claude plugin marketplace add "$repo"
    fi
    if instalado "$plugin"; then echo "  plugin $plugin: ya está"; else run claude plugin install "$plugin" --scope user; fi
  done
fi

# Estilo integrado de Claude Code: lo mantiene Anthropic y añade un recordatorio por turno.
ESTILO="Concise"

# Sin el plugin bajo-consumo (instalación desde zip o clon), la skill se copia a mano.
if instalado "bajo-consumo@claude-bajo-consumo"; then
  echo "== bajo-consumo instalado como plugin: la skill viene de ahí"
elif [ "$SKILL_DIR" != "$CLAUDE_DIR/skills/ahorro-tokens" ]; then
  echo "== Copia local de la skill"
  run mkdir -p "$CLAUDE_DIR/skills"
  run rm -rf "$CLAUDE_DIR/skills/ahorro-tokens"
  run cp -R "$SKILL_DIR" "$CLAUDE_DIR/skills/ahorro-tokens"
fi

if [ "$AJUSTES" = 1 ]; then
  echo "== settings.json"
  actual="$( [ -f "$SETTINGS" ] && cat "$SETTINGS" || echo '{}')"
  nuevo="$actual"

  if printf '%s' "$actual" | jq -e '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW' >/dev/null; then
    echo "  CLAUDE_CODE_AUTO_COMPACT_WINDOW: ya definido, no se toca"
  else
    echo "  CLAUDE_CODE_AUTO_COMPACT_WINDOW=250000"
    nuevo="$(printf '%s' "$nuevo" | jq '.env = ((.env // {}) + {CLAUDE_CODE_AUTO_COMPACT_WINDOW: "250000"})')"
  fi

  DEST_SL="$CLAUDE_DIR/bajo-consumo-statusline.sh"
  if printf '%s' "$actual" | jq -e '.statusLine' >/dev/null; then
    echo "  statusLine: ya hay una, no se toca (la nuestra está en $AQUI/statusline.sh)"
  else
    echo "  statusLine -> $DEST_SL"
    run cp "$AQUI/statusline.sh" "$DEST_SL"
    nuevo="$(printf '%s' "$nuevo" | jq --arg c "bash $DEST_SL" '.statusLine = {type: "command", command: $c}')"
  fi

  previo="$(printf '%s' "$actual" | jq -r '.outputStyle // "por defecto"')"
  echo "  outputStyle: $previo -> $ESTILO"
  nuevo="$(printf '%s' "$nuevo" | jq --arg s "$ESTILO" '.outputStyle = $s')"

  if [ -n "$IDIOMA" ]; then
    echo "  language -> $IDIOMA"
    nuevo="$(printf '%s' "$nuevo" | jq --arg l "$IDIOMA" '.language = $l')"
  fi

  if [ "$nuevo" != "$actual" ]; then
    if [ "$DRY" = 1 ]; then
      echo "  [dry-run] se escribiría settings.json con copia previa"
    else
      mkdir -p "$CLAUDE_DIR"
      if [ -f "$SETTINGS" ]; then
        bak="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"; cp "$SETTINGS" "$bak"; echo "  copia: $bak"
      fi
      printf '%s\n' "$nuevo" > "$SETTINGS"
      echo "  escrito"
    fi
  fi
fi

echo
echo "Hecho. Reinicia Claude Code para cargar plugins, skill y estilo."
echo "Siguiente: /ahorro-tokens, o bash $AQUI/auditar.sh --plugins"
