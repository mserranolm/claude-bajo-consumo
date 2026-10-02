# claude-bajo-consumo

Todo lo necesario para que Claude Code gaste pocos tokens, en un solo paquete.

| Pieza                                                    | Qué ahorra                                                                                 |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Skill `/ahorro-tokens`                                   | Audita dónde se van los tokens fijos de cada turno e instala el resto                      |
| Output style `concisa`                                   | Resultado primero, sin preámbulo ni resumen final. Errores y avisos de seguridad completos |
| [caveman](https://github.com/JuliusBrussee/caveman)      | ~65-75% de tokens de salida                                                                |
| [context-mode](https://github.com/mksglu/context-mode)   | La salida cruda de comandos no entra al contexto                                           |
| [haiku-shunt](https://github.com/mserranolm/haiku-shunt) | Lecturas grandes (>350 líneas) las resume Haiku                                            |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW=250000`                 | Con modelos de 1M, compacta antes de arrastrar cientos de miles de tokens                  |
| Statusline                                               | Contexto y límites 5h/7d a la vista                                                        |

## Instalar

**Opción A, marketplace (recomendada, se actualiza con `claude plugin marketplace update`):**

```bash
claude plugin marketplace add mserranolm/claude-bajo-consumo
claude plugin install bajo-consumo@claude-bajo-consumo --scope user
```

Reinicia Claude Code y escribe `/bajo-consumo:ahorro-tokens`: audita y, con tu permiso, instala el resto.

**Opción B, zip o clon (sin marketplace):**

```bash
unzip claude-bajo-consumo.zip && bash claude-bajo-consumo/install.sh --idioma Español
```

Instala los tres plugins, copia la skill a `~/.claude/skills/ahorro-tokens` y el estilo a `~/.claude/output-styles/concisa.md`, y ajusta `settings.json`. Reinicia y escribe `/ahorro-tokens`.

**Solo auditar:**

```bash
bash plugins/bajo-consumo/skills/ahorro-tokens/scripts/auditar.sh --plugins
```

## Qué toca

- `instalar.sh` es idempotente y hace copia `.bak` fechada de `~/.claude/settings.json`. Define `CLAUDE_CODE_AUTO_COMPACT_WINDOW` y `statusLine` solo si no existen; `outputStyle` lo pone siempre en `concisa` (avisa del valor anterior). Opciones: `--dry-run`, `--sin-plugins`, `--sin-ajustes`, `--idioma <Idioma>`.
- `auditar.sh` es solo lectura: MCP globales, tamaño de `CLAUDE.md`, palancas instaladas, estilo de salida, coste fijo por plugin (`--plugins`) y hooks duplicados.
- No mueve MCP ni recorta tu `CLAUDE.md`: eso lo decides tú, la skill te guía.

Requisitos: `claude`, `jq`, `node`. La statusline pinta el coste en USD solo con `AHORRO_TOKENS_COSTE=1`.

Generar el zip: `bash empaquetar.sh` -> `dist/claude-bajo-consumo.zip`.
