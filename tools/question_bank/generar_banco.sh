#!/usr/bin/env bash
# Genera el banco de preguntas del juego en segundo plano, sin necesidad de VS Code.
#
#   ./tools/question_bank/generar_banco.sh          # 50 preguntas por grado (~7 h)
#   ./tools/question_bank/generar_banco.sh 80       # otra cantidad por grado
#   ./tools/question_bank/generar_banco.sh estado   # ¿sigue trabajando? ultimas lineas del registro
#   ./tools/question_bank/generar_banco.sh parar    # lo para (al relanzarlo sigue donde iba)
#
# Variables opcionales: GRADOS="1 2" (solo esos grados), HILOS=4, MODELO=models/otro.gguf
#
# Mientras trabaja, el PC no se suspende (systemd-inhibit). Se puede cerrar VS Code y la
# terminal: el avance queda en build/banco.log.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$RAIZ"

DB="${DB:-build/knowledge.db}"
SERVIDOR=native/llama/build/host/bin/llama-server
MODELO="${MODELO:-models/qwen2.5-3b-instruct-q4_0.gguf}"
HILOS="${HILOS:-$(nproc)}"
LOG=build/banco.log
PIDF=build/banco.pid

corriendo() {
  [[ -f $PIDF ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null
}

case "${1:-}" in
  parar)
    if corriendo; then
      # El grupo entero: python, llama-server y el bloqueo de suspension. llama-server
      # no se cierra mientras genera: si a los 10 s sigue vivo, se fuerza.
      grupo="$(cat "$PIDF")"
      kill -TERM -- "-$grupo" 2>/dev/null || true
      for _ in $(seq 10); do
        pgrep -g "$grupo" >/dev/null || break
        sleep 1
      done
      pkill -KILL -g "$grupo" 2>/dev/null || true
      echo "Parado. Al relanzarlo seguira donde iba (usa la cache)."
    else
      echo "No esta generando."
    fi
    rm -f "$PIDF"
    exit 0
    ;;
  estado)
    if corriendo; then echo "Generando (PID $(cat "$PIDF")). Ultimas lineas:"; else echo "No esta generando. Ultimas lineas:"; fi
    tail -n 8 "$LOG" 2>/dev/null || echo "(sin registro todavia)"
    exit 0
    ;;
esac

POR_GRADO="${1:-50}"
if ! [[ $POR_GRADO =~ ^[0-9]+$ ]]; then
  echo "Uso: $0 [preguntas_por_grado | estado | parar]" >&2
  exit 1
fi

if corriendo; then
  echo "Ya esta generando (PID $(cat "$PIDF")). Mira el avance con: tail -f $LOG"
  exit 1
fi

falta=0
if [[ ! -x $SERVIDOR ]]; then
  echo "Falta $SERVIDOR: compilalo con los pasos de docs/juego.md (seccion 'Banco de preguntas')." >&2
  falta=1
fi
if [[ ! -f $MODELO ]]; then
  echo "Falta el modelo $MODELO (ver docs/models.md)." >&2
  falta=1
fi
if [[ ! -f $DB ]]; then
  if [[ -f models/knowledge.db ]]; then
    cp models/knowledge.db "$DB"
    echo "Copiada models/knowledge.db a $DB."
  else
    echo "Falta $DB: generala con tools/knowledge_builder/build_knowledge_db.py." >&2
    falta=1
  fi
fi
((falta)) && exit 1

if [[ ! -f $DB.antes-del-banco ]]; then
  cp "$DB" "$DB.antes-del-banco"
  echo "Copia de seguridad: $DB.antes-del-banco"
fi

args=(tools/question_bank/build_question_bank.py --db "$DB" --llama-server "$SERVIDOR"
      --model "$MODELO" --threads "$HILOS" --per-grade "$POR_GRADO")
if [[ -n ${GRADOS:-} ]]; then
  # shellcheck disable=SC2206
  args+=(--grades $GRADOS)
fi

{
  echo "=== $(date '+%F %T') · $POR_GRADO por grado · $HILOS hilos · $(basename "$MODELO") ==="
} >>"$LOG"

# setsid: grupo de procesos propio, para que 'parar' lo cierre todo y cerrar la
# terminal no lo mate.
setsid nohup systemd-inhibit --what=sleep:idle --who="inocencIA" \
  --why="Generando el banco de preguntas del juego" \
  bash -c '
    python3 -u "$@"
    code=$?
    if [ $code -eq 0 ]; then
      echo
      echo "=== Terminado $(date "+%F %T") ==="
      echo "Siguientes pasos:"
      echo " 1. Revisar build/game_questions.csv (borrar o corregir filas)."
      echo " 2. Cargarlo: python3 tools/question_bank/build_question_bank.py --db build/knowledge.db --import-csv build/game_questions.csv"
      echo " 3. Copiar build/knowledge.db a models/knowledge.db y al telefono."
    else
      echo "=== Se detuvo con codigo $code ($(date "+%F %T")). Relanzalo para seguir donde iba. ==="
    fi
    rm -f build/banco.pid
  ' _ "${args[@]}" >>"$LOG" 2>&1 </dev/null &
echo $! >"$PIDF"

echo "Generando en segundo plano (PID $!). El PC no se suspendera mientras tanto."
echo "  Ver el avance:  tail -f $LOG     (Ctrl+C solo deja de mirar)"
echo "  Estado:         $0 estado"
echo "  Parar:          $0 parar"
echo "Ya puedes cerrar VS Code y esta terminal."
