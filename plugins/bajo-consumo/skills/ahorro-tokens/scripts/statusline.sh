#!/bin/bash
# Statusline de Claude Code: modelo | contexto | usage del plan | coste | branch | dir
# LC_ALL=C: sin esto, un locale es_ES rompe printf "%.2f" y escribe "1,0M"
export LC_ALL=C

# ---------------------------------------------------------------------------
# PALETA (256 colores). Cambia solo estos numeros para retocar los colores.
# Ver la rejilla completa:  for i in $(seq 0 255); do printf "\033[38;5;${i}m%3d " $i; done
# ---------------------------------------------------------------------------
C_MODEL=75      # azul cielo    - nombre del modelo
C_LABEL=244     # gris medio    - etiquetas: ctx, 5h, 7d
C_OK=252        # casi blanco   - valor por debajo del 50%: neutro, no grita
C_WARN=214      # ambar         - valor 50-79%
C_CRIT=203      # rojo salmon   - valor >=80%
C_DETAIL=245    # gris claro    - detalles: (80k/1.0M), reset de la ventana
C_EFFORT=245    # gris claro    - effort low/medium/high
C_EFFORT_HI=214 # ambar         - effort xhigh/max: avisa de que gasta mas
C_COST=108      # verde salvia  - coste en USD
C_BRANCH=176    # violeta claro - branch de git
C_DIR=109       # azul apagado  - directorio
C_SEP=239       # gris oscuro   - separador entre grupos
SEP="|"         # separador; prueba tambien: "·" o "" para quitarlo

fg() { printf '\033[38;5;%sm' "$1"; }
R=$'\033[0m'

input=$(cat)

read -r model effort ctx_used ctx_in win five seven five_reset cost cwd <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "unknown" | gsub(" ";"_")),
    (.effort.level // "-" | if . == "" then "-" else . end),
    (.context_window.used_percentage // -1),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 0),
    (.rate_limits.five_hour.used_percentage // -1),
    (.rate_limits.seven_day.used_percentage // -1),
    (.rate_limits.five_hour.resets_at // 0),
    (.cost.total_cost_usd // 0),
    (.workspace.current_dir // .cwd // "")
  ] | @tsv' | tr '\t' ' ')
EOF
model=${model//_/ }

# Color por umbral. Por debajo del 50% va neutro: el color solo aparece
# cuando hay algo que mirar, asi la linea no es un bloque monocromo.
pct_color() {
  if   [ "$1" -ge 80 ]; then printf '%s' "$C_CRIT"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_WARN"
  else printf '%s' "$C_OK"
  fi
}

# Formatea tokens: 68330 -> 68k, 1000000 -> 1.0M
human() {
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%dk", n/1000;
    else printf "%d", n
  }'
}

sep() { [ -n "$SEP" ] && printf ' %s%s%s' "$(fg $C_SEP)" "$SEP" "$R"; }

# --- Modelo ---
printf '%s%s%s' "$(fg $C_MODEL)" "$model" "$R"

# --- Effort: nivel de razonamiento (low|medium|high|xhigh|max) ---
# "-" es el centinela de campo ausente; ver la nota del jq mas arriba.
if [ -n "$effort" ] && [ "$effort" != "-" ]; then
  case "$effort" in
    xhigh|max) ec=$C_EFFORT_HI ;;
    *)         ec=$C_EFFORT ;;
  esac
  printf ' %s%s%s' "$(fg $ec)" "$effort" "$R"
fi

# --- Contexto: % + tokens usados / ventana ---
u=${ctx_used%.*}
if [ "${u:--1}" -ge 0 ] 2>/dev/null; then
  sep
  printf ' %sctx%s %s%s%%%s' "$(fg $C_LABEL)" "$R" "$(fg "$(pct_color "$u")")" "$u" "$R"
  if [ "${win:-0}" -gt 0 ] 2>/dev/null; then
    printf ' %s%s/%s%s' "$(fg $C_DETAIL)" "$(human "$ctx_in")" "$(human "$win")" "$R"
  fi
fi

# --- Rate limits del plan: el "usage" real ---
f=${five%.*}
if [ "${f:--1}" -ge 0 ] 2>/dev/null; then
  sep
  printf ' %s5h%s %s%s%%%s' "$(fg $C_LABEL)" "$R" "$(fg "$(pct_color "$f")")" "$f" "$R"
  left=$(( ${five_reset:-0} - $(date +%s) ))
  [ "$left" -gt 0 ] && printf ' %s%dh%02dm%s' "$(fg $C_DETAIL)" \
    $(( left / 3600 )) $(( (left % 3600) / 60 )) "$R"
fi
s=${seven%.*}
if [ "${s:--1}" -ge 0 ] 2>/dev/null; then
  printf ' %s7d%s %s%s%%%s' "$(fg $C_LABEL)" "$R" "$(fg "$(pct_color "$s")")" "$s" "$R"
fi

# --- Coste de la sesion: solo si AHORRO_TOKENS_COSTE=1 (en plan Max/Pro no informa; lo que limita es 5h/7d) ---
if [ "${AHORRO_TOKENS_COSTE:-0}" = 1 ]; then
  sep; printf ' %s$%.2f%s' "$(fg $C_COST)" "${cost:-0}" "$R"
fi

# --- Git branch ---
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    sep
    printf ' %s%s%s' "$(fg $C_BRANCH)" "$branch" "$R"
  fi
fi

# --- Directorio: 2 ultimos componentes ---
if [ -n "$cwd" ]; then
  printf ' %s%s%s' "$(fg $C_DIR)" \
    "$(printf '%s' "$cwd" | awk -F/ '{if(NF>=2) print $(NF-1)"/"$NF; else print $NF}')" "$R"
fi

printf '\n'
