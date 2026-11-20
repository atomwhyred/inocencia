# Otras plataformas (Windows y Linux): notas para más adelante

Estado (9-nov): **solo Android**. No hay carpetas `windows/` ni `linux/`. La decisión es esperar a ver la
aceptación y las necesidades de los usuarios en Android antes de ampliar.

## ¿Se puede compilar desde este PC (Fedora)?
- **Linux (.deb / .rpm / AppImage): sí.** Flutter para Linux solo compila en Linux. Faltan por instalar
  `cmake`, `ninja-build`, `gtk3-devel`, `pkg-config`, `rpm-build` y `dpkg` (`clang` ya está).
  Un binario hecho en Fedora enlaza con su glibc: para Ubuntu/Debian antiguos, compilar en un contenedor
  con la distro más antigua a soportar (p. ej. Ubuntu 22.04). AppImage o Flatpak sirven a todas las distros con un solo archivo.
- **Windows: no desde aquí.** Flutter no compila de forma cruzada a Windows. Opciones: GitHub Actions con
  `windows-latest` (recomendada, gratis en repos públicos), una máquina virtual con Windows + Visual Studio
  (C++ para escritorio), o un PC con Windows.

## Qué habría que hacer
1. `flutter config --enable-linux-desktop --enable-windows-desktop` y `flutter create --platforms=linux,windows .`
2. **Paquetes**: soportan escritorio `llama_cpp_dart`, `pdfrx`, `flutter_tts`, `sqlite3`,
   `path_provider`. Sin soporte o limitado: `android_alarm_manager_plus` (solo Android), `battery_plus`,
   `flutter_local_notifications`, `image_picker`. Envolverlos con `Platform.isAndroid` o dar versión de escritorio.
3. **Motor del tutor (lo más grande)**: compilar llama.cpp para Linux x86_64 y Windows x64 (CMake,
   `GGML_NATIVE=OFF`, variantes AVX2 como mínimo, `GGML_BACKEND_DL=ON` como en `native/llama/build_android.sh`);
   adaptar `lib/features/tutor/data/native_backends.dart` (hoy busca `libggml-cpu-android_*.so`) para buscar
   `.so`/`.dll` junto al ejecutable; empaquetarlas en `linux/CMakeLists.txt` y `windows/CMakeLists.txt`.
4. **Rutas de datos**: hoy `knowledge.db`, modelos y libros van a `/sdcard/Android/data/...`. En escritorio usar
   `path_provider` y dejar elegir la carpeta de modelos y libros (`external_files_repository_impl.dart`).
5. **Juego en red**: TCP/UDP ya es Dart puro; `LanPlatform` debe ser un no-op en escritorio. Abrir el
   cortafuegos (puertos 47320 UDP y 47321 TCP; Windows Defender pedirá permiso). El juego usa el protocolo v2: sala con
   código de 4 cifras y aviso sin el nombre del niño (ver [juego.md](juego.md)).
6. **Interfaz**: está pensada para móvil vertical; revisar ventana, ratón/teclado y la voz (Linux necesita `speech-dispatcher`).
7. **Empaquetado**: Windows con Inno Setup (.exe) o MSIX (sin firma de código, SmartScreen avisa de editor
   desconocido); .deb con `dpkg-deb` o `fpm`; .rpm con `.spec` + `rpmbuild` o `fpm`. Un `tools/build_desktop.sh`
   al estilo de `tools/build_apks.sh`.
8. **Modelos**: no van en el instalador (1–4 GB); se descargan o se copian como en Android. Explicarlo en la guía de instalación.

## Esfuerzo orientativo
Linux funcionando (sin paquete): 1–2 días, sobre todo llama.cpp y rutas. .deb/.rpm: medio día más.
Windows (CI + instalador): 1–2 días más, sobre todo MSVC y las DLL.

## Orden recomendado si hay demanda
AppImage de Linux (se prueba aquí) → Windows por GitHub Actions → .deb y .rpm.
