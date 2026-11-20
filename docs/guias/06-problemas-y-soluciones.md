# 6. Problemas y soluciones

Busca tu problema en la lista. Si nada funciona, mira el final: **cómo pedir ayuda en el canal**.

## La app no se instala

- **"App no instalada"** al poner una versión nueva: puede que la anterior se instalara desde otro archivo
  distinto. Pregunta en el canal antes de desinstalar: **desinstalar borra perfiles, historial y medallas**.
- **No deja instalar**: permite instalar apps de **origen desconocido** para Telegram o tu gestor de archivos
  (Android lo pregunta al abrir el `.apk`).
- Necesita **Android 10 o superior**.

## La app no encuentra el modelo o la base de libros

1. Comprueba que los archivos están en **`Android/data/com.inocencia.app/files/`** (no en una subcarpeta, salvo los
   PDF, que van en `libros/`).
2. Comprueba que el archivo terminó de descargarse: el modelo recomendado pesa unos **2 GB**. Si pesa menos, está
   cortado: descárgalo otra vez.
3. En **Zona de padres → Archivos** pulsa **Comprobar de nuevo**.

En Android 11 o superior esa carpeta solo se ve con el gestor de archivos del sistema o por cable desde el
ordenador.

## El tutor dice "Preparando a tu tutor…" mucho rato, o la app se cierra sola

El modelo es demasiado grande para la memoria de ese teléfono. Cambia al de **1.5B**
(`qwen2.5-1.5b-instruct-q4_k_m.gguf`) en **Zona de padres → Archivos**.

## El tutor va muy lento

Es normal que tarde **20-40 segundos** en empezar a escribir con el modelo recomendado. Si tarda mucho más:

1. Mientras responde puedes salir de la app, pero **no la cierres desde Recientes**. Si al salir va mucho más
   lento (algunos Xiaomi, Redmi y POCO frenan igualmente las apps), entra en *Ajustes › Aplicaciones › inocencIA ›
   Ahorro de batería* y elige **Sin restricciones**. En Android 13 o superior, permite también las
   **notificaciones** de inocencIA para ver el aviso *"Toco está pensando…"*.
2. Usa el modelo recomendado (`qwen2.5-3b-instruct-q4_0.gguf`), no el de 7B.
3. Haz la **prueba de velocidad**: **Zona de padres → Archivos → Diagnóstico del tutor → Hacer la prueba**
   (1-2 minutos, sin salir de la app). La app se queda con lo más rápido para tu teléfono.
4. Si sigue lento, activa **CPU en modo compatible** en esa misma pantalla, **cierra la app del todo** (quítala de
   las apps recientes), ábrela otra vez y **repite la prueba**.
5. Si el teléfono está **caliente**, déjalo descansar un rato o activa el **modo batería**.

## El tutor no encuentra nada en los libros

Lo dice en la respuesta y sugiere preguntar al maestro. Prueba a preguntar con otras palabras, más parecidas a como
lo dice el libro. Recuerda que solo busca en los libros **del grado del niño**.

## El tutor se equivoca

Puede pasar: es un modelo pequeño que funciona dentro del teléfono. Por eso siempre dice de qué página sale cada
respuesta: **tocad la página y comprobadlo en el libro**. El de 1.5B se equivoca más que el de 3B.

## La lectura en voz alta no suena o habla en inglés

Hay que instalar la voz en español del teléfono (una vez, con internet o copiando el paquete):
*Ajustes › Sistema › Idiomas › Salida de texto a voz › Motor de Google › Instalar datos de voz › Español*.
El camino puede cambiar un poco según la marca del teléfono.

## El juego entre teléfonos no funciona

Mira [5. Jugar → Si algo falla](05-jugar.md#si-algo-falla).

## Olvidé el PIN de padres

No se puede recuperar. La única forma es borrar los datos de la app (*Ajustes › Aplicaciones › inocencIA ›
Almacenamiento › Borrar datos*), que **borra también los perfiles, el historial y las medallas**. También vacía la
carpeta `Android/data/com.inocencia.app/`: **antes, copia el modelo, `knowledge.db` y los libros a otra carpeta**
(por ejemplo Descargas) para no tener que bajarlos otra vez.

## Pedir ayuda en el canal: el diagnóstico

Si el tutor va lento o algo raro pasa, el diagnóstico nos ayuda a ver qué le pasa a tu teléfono:

1. Abre el **Tutor** y haz una pregunta. Espera a que termine **sin salir de la app**.
2. Ve a **Zona de padres → Archivos → Diagnóstico del tutor**.
3. Si puedes, pulsa **Hacer la prueba** y espera a que acabe.
4. Pulsa **Copiar** y pega ese texto en el canal, junto con el **modelo del teléfono** y qué pasa.

El diagnóstico **no lleva nombres ni preguntas** de los niños: solo datos del teléfono y de la velocidad.
