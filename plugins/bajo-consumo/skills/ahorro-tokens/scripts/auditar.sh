#!/usr/bin/env bash
# Audita dónde se van los tokens fijos de cada turno. Solo lectura.
# Uso: auditar.sh [--plugins]   (--plugins mide el coste fijo de cada plugin activo; tarda)
set -uo pipefail

MEDIR_PLUGINS=0
[ "${1:-}" = "--plugins" ] && MEDIR_PLUGINS=1

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_JSON="$HOME/.claude.json"
RECS=()

command -v jq >/dev/null || { echo "Falta jq" >&2; exit 1; }
kb() { awk -v b="$1" 'BEGIN{printf "%.1f KB", b/1024}'; }

echo "== MCP globales (se pagan en cada turno de cada sesión)"
if [ -f "$CLAUDE_JSON" ]; then
  n=$(jq '.mcpServers // {} | length' "$CLAUDE_JSON")
  jq -r '.mcpServers // {} | keys[] | "  - " + .' "$CLAUDE_JSON"
  echo "  total: $n"
  np=$(jq '[.projects // {} | to_entries[] | (.value.mcpServers // {}) | length] | add // 0' "$CLAUDE_JSON")
  echo "  MCP por proyecto: $np"
  [ "$n" -gt 2 ] && RECS+=("Hay $n MCP globales. Deja globales solo los que uses en todos los proyectos; el resto a projects[<ruta>].mcpServers en ~/.claude.json.")
else
  echo "  sin ~/.claude.json"
fi

echo; echo "== CLAUDE.md (se carga entero en cada turno)"
for f in "$CLAUDE_DIR/CLAUDE.md" "./CLAUDE.md" "./.claude/CLAUDE.md"; do
  [ -f "$f" ] || continue
  b=$(wc -c <"$f" | tr -d ' ')
  echo "  $f: $(kb "$b") (~$((b / 4)) tok)"
  [ "$b" -gt 5120 ] && RECS+=("$f pesa $(kb "$b"). Por encima de ~5 KB, mueve lo que no aplica a cada turno a memoria o a una skill.")
done

echo; echo "== Ajustes"
if [ -f "$SETTINGS" ]; then
  w=$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // "no definido"' "$SETTINGS")
  echo "  CLAUDE_CODE_AUTO_COMPACT_WINDOW: $w"
  m=$(jq -r '.model // "por defecto"' "$SETTINGS")
  echo "  model: $m"
  case "$m" in *1m*) [ "$w" = "no definido" ] && RECS+=("Modelo de 1M sin CLAUDE_CODE_AUTO_COMPACT_WINDOW: la sesión puede arrastrar cientos de miles de tokens por turno antes de compactar.") ;; esac
  os=$(jq -r '.outputStyle // "por defecto"' "$SETTINGS")
  echo "  outputStyle: $os"
  [ "$os" = "Concise" ] || RECS+=("outputStyle '$os': el estilo integrado Concise recorta la salida de cada respuesta. instalar.sh lo activa.")
  sl=$(jq -r 'if .statusLine then "sí" else "no" end' "$SETTINGS")
  echo "  statusLine: $sl"
  [ "$sl" = "no" ] && RECS+=("Sin statusline: no ves contexto ni límites mientras trabajas.")
  dup=$(jq '[.hooks // {} | .. | objects | select(.command? // "" | test("haiku-shunt-hook"))] | length' "$SETTINGS")
  if [ "$dup" -gt 0 ] && jq -e '.enabledPlugins["haiku-shunt@haiku-shunt"] == true' "$SETTINGS" >/dev/null; then
    RECS+=("haiku-shunt está como plugin y además con $dup hooks a mano en settings.json: el hook corre dos veces. Quita los de settings.json.")
  fi
else
  echo "  sin settings.json"
fi

echo; echo "== Palancas"
for p in caveman@caveman context-mode@context-mode haiku-shunt@haiku-shunt; do
  if [ -f "$SETTINGS" ] && jq -e --arg k "$p" '.enabledPlugins[$k] == true' "$SETTINGS" >/dev/null; then
    echo "  [x] $p"
  else
    echo "  [ ] $p"; RECS+=("Falta $p: bash $(dirname "$0")/instalar.sh")
  fi
done

echo; echo "== Plugins activos y skills sueltas"
na=$( [ -f "$SETTINGS" ] && jq '[.enabledPlugins // {} | to_entries[] | select(.value == true)] | length' "$SETTINGS" || echo 0)
echo "  plugins activos: $na"
ns=$(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
echo "  skills en $CLAUDE_DIR/skills: $ns (cada descripción entra en cada turno)"

if [ "$MEDIR_PLUGINS" = 1 ] && command -v claude >/dev/null; then
  echo; echo "== Coste fijo por plugin (claude plugin details)"
  total=0
  while read -r p; do
    t=$(claude plugin details "$p" 2>/dev/null | awk '/Always-on:/{gsub(/[~,]/,"",$2); print $2; exit}')
    t=${t:-0}; total=$((total + t))
    printf '  %7s tok  %s\n' "$t" "$p"
  done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS" | sort)
  echo "  total: ~$total tok por sesión"
  [ "$total" -gt 15000 ] && RECS+=("Los plugins suman ~$total tok fijos. Desactiva los que no uses: claude plugin disable <plugin>.")
fi

echo; echo "== Recomendaciones"
if [ ${#RECS[@]} -eq 0 ]; then echo "  nada que corregir"; else
  for r in "${RECS[@]}"; do echo "  - $r"; done
fi
