# Guía para padres y madres

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

## 3. Copiar el modelo y los libros
Necesitas tres archivos:

| Archivo | Qué es | Tamaño aprox. |
|---|---|---|
| `qwen2.5-3b-instruct-q4_k_m.gguf` (o el de 1.5B) | El modelo de IA | 2,1 GB (1,1 GB el pequeño) |
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
  **lectura en voz alta** y **modo batería**.
- **Avisos**: recordatorios de estudio (cada uno con su interruptor).
- **Archivos**: copiar o **Compartir** el modelo, la base y los libros a otro dispositivo, sin internet.

## Lo que ve el niño
- **Mi tutor**: pregunta lo que no entienda; el tutor da un paso y pregunta, no resuelve los ejercicios. Cada
  respuesta dice de qué página del libro sale. El altavoz la lee en voz alta, y el botón de preguntas
  (arriba a la derecha) hace un **quiz** de 3 preguntas.
- **Mis libros**: lee los PDF y se queda en la página donde lo dejó.
- **Mis medallas**: logros y estrellas.
- **Pomodoro**: tras estudiar, Toco avisa del descanso y el chat se bloquea hasta que acabe.
- **Icono de batería**: activa el modo apagón (pantalla negra, tutor más ligero). Con menos del 20 % la app lo
  sugiere, pero nunca lo activa sola.

## Si algo falla
- **El tutor dice "Preparando" mucho rato o no responde**: el modelo es demasiado grande para la RAM. Cambia al
  modelo de 1.5B.
- **No encuentra el modelo**: comprueba que el archivo está en `Android/data/com.inocencia.app/files/` y pulsa
  **Comprobar de nuevo**. En Android 11 o superior esa carpeta solo se ve con el gestor de archivos del sistema o
  por cable desde el ordenador.
- **El tutor no encuentra nada en los libros**: la respuesta lo dice y sugiere preguntar al maestro; prueba a
  preguntarlo con otras palabras.
- **La lectura en voz alta avisa de que no hay voz**: instala los datos de voz en español en
  *Ajustes › Sistema › Idiomas › Salida de texto a voz › Motor de Google › Instalar datos de voz › Español*.
- **El teléfono se calienta y el tutor va más lento**: es normal con el modelo mediano; deja descansar el teléfono
  o activa el modo batería.
- **Respuestas lentas**: un modelo de 3B tarda unos 30-40 segundos por respuesta en un teléfono de gama alta.
- **Desinstalar la app borra los datos** (perfiles, historial, medallas). Para actualizarla, instala el APK nuevo
  encima, sin desinstalar.
