---
name: ahorro-tokens
description: >-
  Audita dónde se van los tokens en Claude Code y aplica la configuración de
  bajo consumo (caveman, context-mode, haiku-shunt, auto-compact, statusline,
  estilo de respuesta conciso,
  MCP por proyecto). Usar cuando el usuario diga "gasto muchos tokens", "se me
  acaba el límite", "ahorrar tokens", "configuración ligera", o pida instalar
  esta configuración en otra máquina.
---

# Ahorro de tokens

Dos scripts en `scripts/` (relativos al directorio base de esta skill). Ejecutarlos, no reimplementarlos.

## Flujo

1. **Auditar primero.** `bash scripts/auditar.sh` (añadir `--plugins` para medir el coste fijo de cada plugin; tarda más). Enseñar al usuario el resumen y las recomendaciones que imprime, con sus cifras.
2. **Instalar con permiso.** Proponer `bash scripts/instalar.sh --dry-run` (con `--idioma Español` si quiere fijar idioma), enseñar lo que haría, y solo tras el sí ejecutar `bash scripts/instalar.sh`. Toca `~/.claude/settings.json` (hace copia `.bak` con fecha) e instala plugins a nivel user.
3. **Lo que el script no hace** (requiere juicio, se hace a mano con el usuario):
   - Mover MCP globales a proyecto: en `~/.claude.json`, de `mcpServers` a `projects["<ruta>"].mcpServers`. Preguntar cuáles usa en todas partes; el resto, a proyecto.
   - Recortar `CLAUDE.md` > 5 KB: lo que no aplica a cada turno va a memoria o a una skill.
   - Desactivar plugins que no usa (`claude plugin disable <plugin>`), empezando por los de más coste fijo.
4. Recordar: los plugins nuevos cargan al **reiniciar** Claude Code.

## Por qué cada palanca

- **MCP global**: inyecta la descripción de todas sus herramientas en cada turno de cada sesión, se use o no. Es la fuga más común.
- **context-mode**: la salida cruda de comandos se queda en un sandbox; al contexto entra solo lo derivado.
- **caveman**: respuestas ~65-75% más cortas sin tocar código ni errores literales.
- **haiku-shunt**: lecturas grandes (por defecto >350 líneas) se desvían a Haiku, que devuelve el resumen.
- **`CLAUDE_CODE_AUTO_COMPACT_WINDOW=250000`**: con modelos de 1M de contexto, compacta antes en vez de arrastrar cientos de miles de tokens por turno.
- **Estilo `concisa`**: resultado primero, sin preámbulo ni resumen final; corta la salida de cada respuesta sin tocar el código.
- **Statusline**: contexto y límites del plan en vivo. Sin ver el número no se controla.
- **Subagentes**: un barrido de muchos ficheros hecho por un subagente devuelve solo la conclusión a la conversación principal.

## Reglas

- No pegar `settings.json` ni `~/.claude.json` completos en la respuesta: llevan rutas, perfiles y a veces secretos. Citar solo claves concretas.
- Si `instalar.sh` falla en un paso, reportar la línea de error exacta; no seguir como si hubiera ido bien.
