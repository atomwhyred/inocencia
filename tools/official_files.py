#!/usr/bin/env python3
"""Genera assets/official/official_files.json: tamaño y SHA-256 de los modelos y la base
de libros que se distribuyen (canal de Telegram, GitHub Releases).

La app compara con esta lista el archivo que vincula el padre y muestra "Archivo
oficial" o "Archivo no reconocido". Así se nota si una knowledge.db o un modelo que
llegó por ShareIt/Zapya/Bluetooth fue modificado por el camino.

Cada vez que se publique una knowledge.db nueva hay que volver a generar la lista y
compilar la app (las bases anteriores siguen en la lista: se añaden, no se borran).

    python3 tools/official_files.py models/*.gguf build/knowledge.db
"""
import hashlib
import json
import os
import sys

DESTINO = os.path.join(os.path.dirname(__file__), "..", "assets", "official", "official_files.json")


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for bloque in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(bloque)
    return h.hexdigest()


def tipo(nombre: str) -> str:
    return "model" if nombre.lower().endswith(".gguf") else "knowledge"


def main(rutas: list[str]) -> None:
    if not rutas:
        print(__doc__)
        sys.exit(1)
    try:
        with open(DESTINO, encoding="utf-8") as f:
            actuales = json.load(f)["files"]
    except FileNotFoundError:
        actuales = []
    por_hash = {e["sha256"]: e for e in actuales}
    for ruta in rutas:
        nombre = os.path.basename(ruta)
        h = sha256(ruta)
        por_hash[h] = {"name": nombre, "kind": tipo(nombre), "size": os.path.getsize(ruta), "sha256": h}
        print(f"{h}  {nombre}")
    salida = {"version": 1, "files": sorted(por_hash.values(), key=lambda e: (e["kind"], e["name"], e["size"]))}
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Escrito {os.path.normpath(DESTINO)} ({len(salida['files'])} archivos)")


if __name__ == "__main__":
    main(sys.argv[1:])
