# Guía para padres y madres

> Hay guías más cortas, pensadas para compartir, en [guias/](guias/README.md).

inocencIA es un tutor que funciona **sin internet**. Para eso necesita tres cosas en el teléfono o la tablet:
la app, el **modelo de IA** (un archivo `.gguf`) y los **libros** (la base `knowledge.db` y los PDF). Se copian una
sola vez.

## 1. Instalar la app
1. Copia el archivo `.apk` al teléfono (cable, tarjeta SD o Bluetooth) y ábrelo.
2. Android pedirá permiso para instalar apps de origen desconocido: acéptalo solo para este archivo.
3. Necesita **Android 10 o superior**. Para el tutor conviene tener **al menos 7 GB de RAM** (con 8 GB va bien
   el modelo mediano; con menos, usa el modelo pequeño).

## 2. Crear tu PIN
Al abrir la app por primera vez te pide tu nombre y un **PIN de 4 o 6 dígitos**. Con él entras a la
**Zona de padres** (el candado de arriba a la derecha). Apúntalo: si lo olvidas, no hay forma de recuperarlo.
La app no acepta PIN obvios (0000, 1234, 1212, 2580…): elige uno que un niño no adivine. Si alguien falla varias
veces, la entrada se bloquea un rato, y cambiar la hora del teléfono no lo evita. La zona de padres se cierra sola
cuando sales de la app y tras 10 minutos sin tocarla.

## 3. Copiar el modelo y los libros
Necesitas tres archivos:

| Archivo | Qué es | Tamaño aprox. |
|---|---|---|
| `qwen2.5-3b-instruct-q4_0.gguf` (o el de 1.5B) | El modelo de IA | 2,0 GB (1,1 GB el pequeño) |
| `knowledge.db` | Los libros que consulta el tutor | según los libros |
| PDF de los libros (`6to_matematica.pdf`...) | Para leerlos en "Mis libros" | varios cientos de MB |

Cópialos a la carpeta de la app: `Android/data/com.inocencia.app/files/` (el modelo y `knowledge.db`) y
`Android/data/com.inocencia.app/files/libros/` (los PDF). Funciona en la memoria interna o en la tarjeta SD.
Si los PDF ya están en otra carpeta (Descargas, tarjeta SD), no hace falta moverlos: se vinculan en el paso 4.

## 4. Vincular los archivos
1. Entra en la **Zona de padres** (candado + PIN) → pestaña **Archivos**.
2. La app muestra qué falta y qué modelo recomienda para la RAM de este teléfono.
3. En **Modelo de IA** y **Base de libros** pulsa **Detectar** (o **Comprobar de nuevo**): si los copiaste a la
   carpeta de la app, aparecen solos.
4. En **Libros para leer (PDF)** pulsa **Detectar** para que la app busque la carpeta, o **Buscar carpeta** para
   elegirla tú y **Usar esta carpeta**.
5. El **Modelo recomendado** se puede cambiar: el de 1.5B es más rápido pero se equivoca más.

La primera vez, al abrir el tutor, el modelo tarda unos segundos en cargar ("Preparando").

## 5. Crear los perfiles de los niños
**Zona de padres → Perfiles → Nuevo perfil**: nombre, grado (1.º a 6.º) y avatar. Cada niño tiene su propio
historial, su página en cada libro y sus medallas. El grado sube solo con los años. Puedes ponerle un PIN
al perfil de un niño mayor.

## 6. Ajustes de la Zona de padres
- **Apariencia**: tema claro/oscuro, tamaño de Toco, **Pomodoro** (15+5 min de 1.º a 3.º, 20+5 min de 4.º a 6.º),
  **lectura en voz alta**, **modo batería** y **Enviar la foto en el juego en red** (apagado: en las partidas con
  otros teléfonos el niño sale con un emoji y su foto no sale del teléfono; encendido: los demás ven una miniatura).
- **Avisos**: recordatorios de estudio (cada uno con su interruptor). En la pantalla de bloqueo solo se ve que hay un
  aviso de inocencIA; el nombre del niño aparece con el teléfono desbloqueado.
- **Archivos**: copiar o **Compartir** el modelo, la base y los libros a otro dispositivo, sin internet. Cada
  archivo dice si es **oficial** (coincide con el publicado) o **no reconocido**: si un archivo llegó por Bluetooth o
  ShareIt y no lo reconoce, vuelve a copiarlo desde el canal oficial, porque pudo cambiar por el camino.

## Lo que ve el niño
- **Mi tutor**: pregunta lo que no entienda; el tutor da un paso y pregunta, no resuelve los ejercicios. Cada
  respuesta dice de qué página del libro sale. El altavoz la lee en voz alta, y el botón de preguntas
  (arriba a la derecha) hace un **quiz** de 3 preguntas.
- **Mis libros**: lee los PDF y se queda en la página donde lo dejó.
- **Mis medallas**: logros y estrellas (se abren desde la tarjeta roja del inicio).
- **Jugar**: "Carrera de tocororos" (gana quien llegue antes) o "Entre todos" (cooperativo). Cada niño responde
  preguntas de **su** grado, así pueden jugar hermanos o amigos de grados distintos. Se juega **en un teléfono**
  (2-4 niños se lo pasan por turnos) o **con otros teléfonos**: uno crea la sala y los demás se unen con el **código de
  4 cifras** que sale en su pantalla, conectados al mismo Wi-Fi o al **punto de acceso** del que crea la sala (no hace
  falta tener datos ni internet). Todos los teléfonos deben tener la misma versión de inocencIA.
  Las preguntas salen del banco del juego que viene en la base de libros y de las tarjetas de cada niño.
- **Pomodoro**: tras estudiar, Toco avisa del descanso y el chat se bloquea hasta que acabe.
- **Icono de batería**: activa el modo apagón (pantalla negra, tutor más ligero). Con menos del 20 % Toco lo
  sugiere (en su globo del inicio o como un mensaje en el chat), pero nunca lo activa solo.

## El permiso de red
Para jugar entre teléfonos, Android exige que la app declare el permiso **INTERNET**, aunque la conexión sea solo
dentro de casa o del aula. inocencIA **no se conecta nunca a internet**: solo habla con los teléfonos de la misma
red Wi-Fi o del mismo punto de acceso, y solo mientras hay una partida abierta.

## Si algo falla
- **En "Con otros teléfonos" no aparece la sala**: comprobad que todos están en el mismo Wi-Fi o punto de acceso y que
  todos tienen la misma versión de la app. Algunas redes no dejan anunciar salas: escribid la dirección que muestra el
  teléfono que creó la sala y, al entrar, el código.
- **"El código de la sala no es ese"**: mira bien las 4 cifras en el teléfono que creó la sala. Tras 5 códigos
  equivocados desde un mismo teléfono ya no se le deja entrar mientras esa sala siga abierta; cierra la sala y crea otra.
- **La sala aparece y desaparece de la lista**: la lista se borra sola cuando el anfitrión deja de anunciarla (por
  ejemplo, al empezar la partida).
- **"No se pudo abrir la sala"** o no se puede entrar: puede que el teléfono tenga apagado el acceso a la red para
  inocencIA (*Ajustes › Aplicaciones › inocencIA › Datos móviles y Wi-Fi*). Actívalo para jugar entre teléfonos; la
  app sigue sin conectarse a internet.
- **"No hay preguntas para jugar"**: la base de libros no trae el banco del juego y el niño tiene menos de 3
  tarjetas. Crea tarjetas desde el tutor o copia una base de libros con el banco (ver `docs/juego.md`).
- **El tutor dice "Preparando" mucho rato o no responde**: el modelo es demasiado grande para la RAM. Cambia al
  modelo de 1.5B.
- **No encuentra el modelo**: comprueba que el archivo está en `Android/data/com.inocencia.app/files/` y pulsa
  **Comprobar de nuevo**. En Android 11 o superior esa carpeta solo se ve con el gestor de archivos del sistema o
  por cable desde el ordenador.
- **El tutor no encuentra nada en los libros**: la respuesta lo dice y sugiere preguntar al maestro; prueba a
  preguntarlo con otras palabras.
- **La lectura en voz alta avisa de que no hay voz** (o la voz habla otro idioma): la app lee en español; hay que
  tener instalada la voz en español en el teléfono: instala los datos de voz en español en
  *Ajustes › Sistema › Idiomas › Salida de texto a voz › Motor de Google › Instalar datos de voz › Español*.
- **El teléfono se calienta y el tutor va más lento**: es normal con el modelo mediano; deja descansar el teléfono
  o activa el modo batería.
- **Respuestas lentas**: un modelo de 3B tarda unos 20-30 segundos por respuesta en un teléfono de gama alta. Mientras
  responde se puede salir de la app o apagar la pantalla (sale el aviso *"Toco está pensando…"*), pero **no la
  cierres desde Recientes**: eso detiene la respuesta. Si aun así va mucho más
  lento, entra en **Zona de padres → Archivos → Diagnóstico del tutor** y pulsa **Hacer la prueba** (1-2 minutos, sin
  salir de la app). La app mide qué configuración va más rápida en ese teléfono y la usa desde entonces (**Volver a
  automático** la deshace). Si sigue lento, activa **CPU en modo compatible**, cierra la app del todo, vuelve a abrirla
  y repite la prueba. Pulsa **Copiar** y envía ese texto a quien mantiene la app. No lleva nombres ni preguntas.
- **Desinstalar la app borra los datos** (perfiles, historial, medallas). Para actualizarla, instala el APK nuevo
  encima, sin desinstalar. Cada actualización lleva un número de versión nuevo (1.0.1, 1.0.2…).
  **Excepción:** la primera versión firmada con la clave propia no se puede instalar encima de las anteriores (Android
  lo rechaza porque cambia la firma): hay que desinstalar una vez, así que antes copia lo que quieras conservar.
