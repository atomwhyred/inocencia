# Juego: "Carrera de tocororos" y "Entre todos"

Los niños juegan con lo que aprenden, sin internet. **Cada niño responde preguntas de su grado** (de sus libros y
de sus tarjetas), así que un niño de 2.º puede jugar con uno de 6.º. En la sala se ve el avatar, el nombre y el
grado de cada uno.

- **Carrera**: pista de 10 casillas; acierto +1, acierto con una tarjeta propia +2. La partida solo termina al
  cerrar una ronda (todos responden el mismo número de veces). Si nadie llega en 15 rondas, gana quien va delante.
- **Entre todos**: los aciertos de todos llenan una barra (6 por jugador) para que Toco llegue a su nido en 10 rondas.
- Tiempo por pregunta: 35 s en 1.º-2.º, 25 s desde 3.º.
- Estrellas al terminar (a los niños de cada teléfono): 1 por jugar, +1 cada 3 aciertos, +2 si gana.

Código: `lib/features/game/` (reglas puras en `domain/game_rules.dart`).

## Modos
- **En este teléfono**: 2-4 perfiles del teléfono se lo pasan por turnos ("Le toca a Ana").
- **Con otros teléfonos** (hasta 6): uno crea la sala; los demás la ven en "Unirme" o escriben su IP.
  - Red: Wi-Fi común o el **punto de acceso** del anfitrión (sin datos). TCP 47321 para la partida y avisos UDP de
    difusión en 47320 (`domain/lan_protocol.dart`, JSON por líneas con versión).
  - Seguridad (protocolo v2): el anfitrión muestra un **código de 4 cifras** que hay que escribir para entrar;
    tras 5 códigos erróneos desde una IP, esa IP queda fuera hasta que se cierre la sala. El aviso UDP solo lleva
    un nombre de sala al azar ("Sala del Sinsonte"), el grado y el modo: nunca el nombre del niño. Todo lo que llega
    se limita en `domain/net_sanitize.dart`: líneas de hasta 256 KB, nombres de 24 caracteres, avatares que sean
    emoji o una miniatura PNG pequeña (nunca `photo:<ruta>`), como mucho 8 conexiones, un solo saludo por
    conexión y 8 s para presentarse. La miniatura de la foto solo se envía si el padre lo activa en
    **Zona de padres → Apariencia → Enviar la foto en el juego en red** (apagado por defecto).
  - Cada teléfono saca las preguntas de **su** base y sus tarjetas; el anfitrión solo lleva el reloj y los puntos.
  - Android: `INTERNET` (obligatorio para cualquier socket), `ACCESS_WIFI_STATE` y `CHANGE_WIFI_MULTICAST_STATE`
    (el `MulticastLock` de `LanBridge.kt` deja recibir los avisos). La app nunca sale a internet.

## Banco de preguntas (en el PC)

El modelo del teléfono tarda ~10 s por pregunta: no sirve para un juego en vivo. El banco se prepara en el PC y
va dentro de `knowledge.db` (tabla opcional `game_questions`, ver `knowledge_db_schema.md`).

```bash
# 1. llama-server para el PC (una vez; mismo commit de llama.cpp que la app)
CM=$(ls -d ~/Android/Sdk/cmake/*/bin | sort -V | tail -1); export PATH="$CM:$PATH"
cmake -S native/llama/src/llama.cpp -B native/llama/build/host -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLAMA_CURL=OFF -DLLAMA_BUILD_SERVER=ON -DGGML_NATIVE=ON
cmake --build native/llama/build/host -j4 --target llama-server

# 2. Generar (reanudable: la caché está en build/question_cache.json)
python3 tools/question_bank/build_question_bank.py --db build/knowledge.db \
  --llama-server native/llama/build/host/bin/llama-server \
  --model models/qwen2.5-3b-instruct-q4_0.gguf --per-grade 50

# 3. Revisar build/game_questions.csv (borrar o corregir filas) y volver a cargarlo
python3 tools/question_bank/build_question_bank.py --db build/knowledge.db --import-csv build/game_questions.csv
```

### Generar sin VS Code abierto (recomendado para las 7 h)

```bash
cd ~/Escritorio/DeepTutor
./tools/question_bank/generar_banco.sh          # 50 por grado; o ./generar_banco.sh 80
tail -f build/banco.log                         # ver el avance (Ctrl+C solo deja de mirar)
./tools/question_bank/generar_banco.sh estado   # ¿sigue trabajando?
./tools/question_bank/generar_banco.sh parar    # parar; al relanzarlo sigue donde iba
```

Trabaja en segundo plano, así que se pueden cerrar VS Code y la terminal. Mientras dura, el PC no se suspende
(`systemd-inhibit`). Usa todos los núcleos, guarda una copia de `build/knowledge.db` en
`build/knowledge.db.antes-del-banco` y al terminar escribe en el registro los pasos 3 y 4. Variables opcionales:
`GRADOS="1 2"`, `HILOS=4`, `MODELO=...`, `DB=...`.

Primera generación completa (9-nov): 300 preguntas, 50 por grado, ~50 s por fragmento con el 3B Q4_0 en el PC.

Filtros (los mismos que el quiz de la app, más algunos propios): la respuesta correcta aparece en el texto del
libro; nada de páginas, figuras, tablas, poemas ni "el texto"; opciones distintas y cortas; la respuesta no puede
estar en la pregunta; se prefieren los libros a los cuadernos y se omite Inglés (salían palabras sin sentido).

**Rendimiento medido (8-nov, Ryzen 3 3200U, 4 hilos, 3B Q4_0):** ~63 s por fragmento y ~0,75 preguntas válidas
por fragmento, es decir ~85 s por pregunta. 50 preguntas por grado (6 grados) ≈ 7 horas: una noche. Se puede
parar y seguir, y ampliar después con `--per-grade` mayor.

Aun con los filtros, **conviene que un adulto revise el CSV**: el 3B a veces marca como correcta una respuesta
discutible (en la prueba, "¿Qué es Nova?" → "Software Libre" en vez de "sistema operativo").

Pruebas: `python3 -m unittest discover -s tools/question_bank`.
