/*
 * Toco en 3D para la portada de la landing.
 *
 * Se monta con las mismas capas que usa la app (assets/mascot/, ver layers.json) y la
 * misma animación de reposo que lib/features/mascot/presentation/mascot_pose.dart:
 * respira, parpadea, mueve cabeza, ala y cola, y mira al dedo o al ratón. Al empezar,
 * un libro se abre y Toco sale volando de él; luego se queda encima mientras el libro
 * pasa páginas. Al tocarlo da un saltito con estrellas. Alrededor flotan letras, números
 * y figuras de los libros, y de noche hay estrellas.
 *
 * Es solo un adorno: si algo falla (sin WebGL, poca memoria, ahorro de datos, movimiento
 * reducido) se queda la imagen fija de Toco que ya trae la página.
 *
 * Se empaqueta con ../tools/landing_build.sh en landing/js/escena.js.
 */
import {
  CanvasTexture,
  Group,
  Mesh,
  MeshBasicMaterial,
  PerspectiveCamera,
  PlaneGeometry,
  Points,
  PointsMaterial,
  BufferGeometry,
  Float32BufferAttribute,
  Scene,
  Sprite,
  SpriteMaterial,
  SRGBColorSpace,
  TextureLoader,
  Vector3,
  WebGLRenderer,
  Color,
  BoxGeometry,
  MeshLambertMaterial,
  AmbientLight,
  DirectionalLight,
  DoubleSide,
} from "three";

// ------------------------------------------------------------------ datos de la app

/** assets/mascot/layers.json (lienzo 437×720, y hacia abajo). */
const CANVAS = [437, 720];
const LAYERS = {
  tail: { x: 2, y: 399, w: 276, h: 319 },
  body: { x: 87, y: 150, w: 308, h: 361 },
  wing: { x: 85, y: 193, w: 159, h: 282 },
  branch: { x: 117, y: 387, w: 104, h: 73 },
  head: { x: 125, y: 2, w: 310, h: 226 },
};
const PIVOTS = { head: [274.3, 203.4], wing: [201.4, 218.7], tail: [180.5, 449.9] };
const MAX_DEG = { head: 8, wing: 8, tail: 10 };
const FEET = [240, 420];
const EYE = {
  cx: 271.5, cy: 125.0, r: 27.8, rInner: 21.2,
  pupil: { x: 250, y: 107, w: 43, h: 42 },
  maxGaze: 4.9, lid: "#12397B",
};
/** Profundidad de cada capa (en px del lienzo): da el paralaje al girar. */
const DEPTH = { tail: -26, body: 0, wing: 14, branch: 18, head: 24 };
const ORDER = ["tail", "body", "wing", "branch", "head"];

/** Altura de Toco en unidades de la escena. */
const TOCO_H = 3.6;
const PX = TOCO_H / CANVAS[1];

// ------------------------------------------------------------------ comprobaciones

const stage = document.querySelector("[data-escena]");
const motionOk = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const conn = navigator.connection;
const lowMem = typeof navigator.deviceMemory === "number" && navigator.deviceMemory <= 2;
if (stage && motionOk && !(conn && conn.saveData) && !lowMem) start(stage).catch(() => {});

// ------------------------------------------------------------------ utilidades

const TAU = Math.PI * 2;
const wave = (t, p, ph = 0) => Math.sin(TAU * (t / p + ph));
const clamp = (v, m) => Math.max(-m, Math.min(m, v));
const smooth = (x) => x * x * (3 - 2 * x);
const hash = (k) => { const x = Math.sin(k * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

/** Parpadeo de la app: uno por tramo de 4 s, a veces doble. */
function blink(t) {
  const seg = 4, k = Math.floor(t / seg), local = t - k * seg, i = ((k % 6) + 6) % 6;
  const at = 0.9 + hash(i) * 2.2;
  let lid = blinkCurve(local - at);
  if (hash(i + 11) > 0.7) lid = Math.max(lid, blinkCurve(local - at - 0.34));
  return lid;
}
function blinkCurve(x) {
  const dur = 0.22;
  if (x <= 0 || x >= dur) return 0;
  return Math.pow(Math.sin((Math.PI * x) / dur), 0.6);
}

/** Mirada que vaga cuando nadie mueve el dedo: cada 3 s otro punto. */
function wander(t) {
  const seg = 3, k = Math.floor(t / seg), local = t - k * seg;
  const target = (n) => [(hash((((n % 8) + 8) % 8) + 40) * 2 - 1) * 0.75, (hash((((n % 8) + 8) % 8) + 70) * 2 - 1) * 0.45];
  const a = target(k - 1), b = target(k), u = smooth(Math.min(1, local / 0.45));
  return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u];
}

/** Lienzo del canvas (px, y abajo) → escena (y arriba), centrado en el lienzo. */
const toWorld = (x, y) => [(x - CANVAS[0] / 2) * PX, -(y - CANVAS[1] / 2) * PX];

function cssColor(name, fallback) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return v || fallback;
}

function isDark() {
  const t = document.documentElement.getAttribute("data-theme");
  return t ? t === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function loadTexture(loader, url) {
  return new Promise((resolve, reject) => {
    loader.load(url, (tex) => { tex.colorSpace = SRGBColorSpace; resolve(tex); }, undefined, reject);
  });
}

/** Textura blanca con un texto (se tiñe con el color del material). */
function glyphTexture(text) {
  const size = 128;
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  const fs = text.length > 2 ? 52 : text.length > 1 ? 70 : 92;
  g.font = `700 ${fs}px ui-rounded, "SF Pro Rounded", "Nunito", system-ui, sans-serif`;
  g.textAlign = "center";
  g.textBaseline = "middle";
  g.fillStyle = "#fff";
  g.fillText(text, size / 2, size / 2 + fs * 0.05);
  const tex = new CanvasTexture(c);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function starTexture() {
  const size = 64;
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  g.translate(size / 2, size / 2);
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 ? 11 : 28;
    const a = (i * Math.PI) / 5 - Math.PI / 2;
    g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  g.closePath();
  g.fillStyle = "#fff";
  g.fill();
  const tex = new CanvasTexture(c);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

/** Punto redondo y difuso para el cielo. */
function dotTexture() {
  const size = 32;
  const c = document.createElement("canvas");
  c.width = c.height = size;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(16, 16, 0, 16, 16, 16);
  grad.addColorStop(0, "rgba(255,255,255,1)");
  grad.addColorStop(0.4, "rgba(255,255,255,.8)");
  grad.addColorStop(1, "rgba(255,255,255,0)");
  g.fillStyle = grad;
  g.fillRect(0, 0, size, size);
  return new CanvasTexture(c);
}

/** Salida con un pequeño rebote al final (0..1). */
function easeOutBack(x) {
  const c1 = 1.5, c3 = c1 + 1;
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
}
const clamp01 = (x) => Math.max(0, Math.min(1, x));

function canvasTexture(w, h, draw) {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  draw(c.getContext("2d"), w, h);
  const t = new CanvasTexture(c);
  t.colorSpace = SRGBColorSpace;
  return t;
}

/** Tapa del libro: azul, franja roja junto al lomo y una estrella blanca. */
function coverTexture() {
  return canvasTexture(256, 340, (g, w, h) => {
    g.fillStyle = "#0035ad";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#dc241f";
    g.fillRect(0, 0, 34, h);
    g.fillStyle = "rgba(255,255,255,.18)";
    g.fillRect(70, 230, 140, 14);
    g.fillRect(70, 256, 100, 14);
    g.translate(140, 130);
    g.beginPath();
    for (let i = 0; i < 10; i++) {
      const r = i % 2 ? 22 : 54;
      const a = (i * Math.PI) / 5 - Math.PI / 2;
      g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    g.closePath();
    g.fillStyle = "#fff";
    g.fill();
  });
}

/** Página: renglones y un triángulo, como un libro de Matemática. */
function pageTexture() {
  return canvasTexture(256, 340, (g, w, h) => {
    g.fillStyle = "#fbf8ef";
    g.fillRect(0, 0, w, h);
    g.fillStyle = "#c9cede";
    for (let y = 40; y < 150; y += 22) g.fillRect(28, y, w - 56 - ((y * 7) % 60), 7);
    g.strokeStyle = "#0035ad";
    g.lineWidth = 6;
    g.lineJoin = "round";
    g.beginPath();
    g.moveTo(70, 290);
    g.lineTo(186, 290);
    g.lineTo(110, 190);
    g.closePath();
    g.stroke();
    g.fillStyle = "#dc241f";
    g.font = "700 30px system-ui, sans-serif";
    g.fillText("193", w - 80, h - 18);
  });
}

// ------------------------------------------------------------------ escena

async function start(stage) {
  const canvas = stage.querySelector("canvas");
  let renderer;
  try {
    renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "low-power" });
  } catch (e) {
    return; // sin WebGL: se queda la imagen
  }
  const mem = navigator.deviceMemory || 8;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, mem <= 4 ? 1.5 : 2));
  renderer.setClearColor(0x000000, 0);

  const scene = new Scene();
  const camera = new PerspectiveCamera(30, 1, 0.1, 60);
  camera.position.set(0, 0, 9.5);

  // ---- Toco
  const loader = new TextureLoader();
  const names = [...ORDER, "eye"];
  const tex = Object.fromEntries(
    await Promise.all(names.map(async (n) => [n, await loadTexture(loader, `img/toco/${n}.webp`)])),
  );

  const rig = new Group(); // Toco y el libro: gira hacia el puntero
  scene.add(rig);
  const toco = new Group(); // sale del libro
  const body = new Group(); // respira y salta (anclado en las patas)
  const [fx, fy] = toWorld(FEET[0], FEET[1]);
  body.position.set(fx, fy, 0);
  toco.add(body);
  rig.add(toco);
  const TOCO_Y = 0.55, TOCO_S = 0.84;
  const tocoMats = [];

  const parts = {};
  ORDER.forEach((name, i) => {
    const L = LAYERS[name];
    const mesh = new Mesh(
      new PlaneGeometry(L.w * PX, L.h * PX),
      new MeshBasicMaterial({ map: tex[name], transparent: true, depthWrite: false }),
    );
    tocoMats.push(mesh.material);
    mesh.renderOrder = 10 + i;
    const [cx, cy] = toWorld(L.x + L.w / 2, L.y + L.h / 2);
    const z = DEPTH[name] * PX;
    const pivot = PIVOTS[name];
    if (pivot) {
      const holder = new Group();
      const [px, py] = toWorld(pivot[0], pivot[1]);
      holder.position.set(px - fx, py - fy, z);
      mesh.position.set(cx - px, cy - py, 0);
      holder.add(mesh);
      body.add(holder);
      parts[name] = holder;
    } else {
      mesh.position.set(cx - fx, cy - fy, z);
      body.add(mesh);
    }
  });

  // Ojo: un lienzo pequeño que se redibuja con la pupila y el párpado (va con la cabeza).
  const eyeCanvas = document.createElement("canvas");
  const EYE_PX = 96;
  eyeCanvas.width = eyeCanvas.height = EYE_PX;
  const eg = eyeCanvas.getContext("2d");
  const eyeTex = new CanvasTexture(eyeCanvas);
  eyeTex.colorSpace = SRGBColorSpace;
  const eyeSpan = EYE.r * 2 + 4; // px del lienzo que cubre la textura
  const eyeMesh = new Mesh(
    new PlaneGeometry(eyeSpan * PX, eyeSpan * PX),
    new MeshBasicMaterial({ map: eyeTex, transparent: true, depthWrite: false }),
  );
  eyeMesh.renderOrder = 20;
  tocoMats.push(eyeMesh.material);
  {
    const [ex, ey] = toWorld(EYE.cx, EYE.cy);
    const [hx, hy] = toWorld(PIVOTS.head[0], PIVOTS.head[1]);
    eyeMesh.position.set(ex - hx, ey - hy, 0.002);
    parts.head.add(eyeMesh);
  }
  const pupilImg = tex.eye.image;
  let lastEye = "";
  function drawEye(gx, gy, lid) {
    const key = `${gx.toFixed(2)}|${gy.toFixed(2)}|${lid.toFixed(2)}`;
    if (key === lastEye) return;
    lastEye = key;
    const k = EYE_PX / eyeSpan;
    eg.setTransform(1, 0, 0, 1, 0, 0);
    eg.clearRect(0, 0, EYE_PX, EYE_PX);
    eg.setTransform(k, 0, 0, k, EYE_PX / 2 - EYE.cx * k, EYE_PX / 2 - EYE.cy * k);
    if (lid < 0.98) {
      eg.save();
      eg.beginPath();
      eg.arc(EYE.cx, EYE.cy, EYE.rInner, 0, TAU);
      eg.clip();
      eg.fillStyle = "#E2E6EF";
      eg.fill();
      const P = EYE.pupil;
      eg.drawImage(pupilImg, P.x + gx * EYE.maxGaze, P.y + gy * EYE.maxGaze, P.w, P.h);
      eg.restore();
    }
    if (lid > 0.01) {
      eg.save();
      eg.beginPath();
      eg.arc(EYE.cx, EYE.cy, EYE.r, 0, TAU);
      eg.clip();
      eg.fillStyle = EYE.lid;
      eg.fillRect(EYE.cx - 2 * EYE.r, EYE.cy - 3 * EYE.r, 4 * EYE.r, 2 * EYE.r * lid + 2 * EYE.r);
      eg.restore();
      if (lid > 0.7) {
        const a = Math.min(1, (lid - 0.7) / 0.3);
        eg.strokeStyle = `rgba(175,198,242,${a})`;
        eg.lineWidth = EYE.r * 0.17;
        eg.lineCap = "round";
        eg.beginPath();
        eg.moveTo(EYE.cx - EYE.r * 0.72, EYE.cy + EYE.r * 0.02);
        eg.quadraticCurveTo(EYE.cx, EYE.cy + EYE.r * 0.62, EYE.cx + EYE.r * 0.72, EYE.cy + EYE.r * 0.02);
        eg.stroke();
      }
    }
    eyeTex.needsUpdate = true;
  }

  // ---- el libro (de él sale Toco)
  scene.add(new AmbientLight(0xffffff, 1.6));
  const sun = new DirectionalLight(0xffffff, 1.6);
  sun.position.set(2, 5, 6);
  scene.add(sun);

  const W = 1.2, H = 1.6, CT = 0.04, BT = 0.12; // media anchura, alto, tapa y bloque de hojas
  const ZC = CT + BT / 2 + CT / 2; // eje del lomo: a media altura del libro cerrado
  const coverTex = coverTexture(), pageTex = pageTexture();
  const blue = new MeshLambertMaterial({ color: 0x0035ad });
  const inside = new MeshLambertMaterial({ color: 0xdce4ff });
  const edge = new MeshLambertMaterial({ color: 0xefe9da });
  const page = new MeshLambertMaterial({ map: pageTex });
  const coverMats = [blue, blue, blue, blue, new MeshLambertMaterial({ map: coverTex }), inside];
  const blockMats = [edge, edge, edge, edge, page, page];

  const book = new Group();
  book.position.set(0, -1.75, 0.35);
  book.rotation.x = -1.02; // tumbado, visto desde delante y un poco arriba
  rig.add(book);
  const bookInner = new Group(); // centra el libro abierto
  book.add(bookInner);

  const backCover = new Mesh(new BoxGeometry(W + 0.06, H + 0.08, CT), coverMats);
  backCover.position.set(W / 2, 0, CT / 2);
  const pagesR = new Mesh(new BoxGeometry(W, H, BT), blockMats);
  const hinge = new Group(); // la tapa gira sobre el lomo
  hinge.position.z = ZC;
  const frontCover = new Mesh(new BoxGeometry(W + 0.06, H + 0.08, CT), coverMats);
  frontCover.position.set(W / 2, 0, CT + BT + CT / 2 - ZC);
  const pagesL = new Mesh(new BoxGeometry(W, H, BT), blockMats);
  hinge.add(frontCover, pagesL);
  bookInner.add(backCover, pagesR, hinge);

  // Hoja que pasa, algo curvada.
  const leafGeo = new PlaneGeometry(W * 0.98, H * 0.98, 12, 1);
  const leafBase = Float32Array.from(leafGeo.attributes.position.array);
  const leaf = new Mesh(leafGeo, new MeshLambertMaterial({ map: pageTex, side: DoubleSide }));
  const leafHinge = new Group();
  leafHinge.add(leaf);
  leaf.position.x = (W * 0.98) / 2;
  leafHinge.visible = false;
  bookInner.add(leafHinge);
  book.traverse((o) => { if (o.isMesh) o.renderOrder = 25; });

  /** p: 0 cerrado → 1 abierto. */
  function setBook(p) {
    const sL = Math.max(0.001, 0.5 * p), sR = 1 - 0.5 * p;
    pagesR.scale.z = sR;
    pagesR.position.set(W / 2, 0, CT + (BT * sR) / 2);
    pagesL.scale.z = sL;
    pagesL.position.set(W / 2, 0, CT + BT - (BT * sL) / 2 - ZC);
    pagesL.visible = p > 0.02;
    hinge.rotation.y = -Math.PI * 0.985 * p;
    bookInner.position.x = -W / 2 + (W / 2) * p; // cerrado centrado; abierto, el lomo al centro
    leafHinge.position.z = CT + BT * sR + 0.004;
  }

  /** u: 0..1 de una hoja pasando de derecha a izquierda. */
  function setLeaf(u) {
    leafHinge.visible = u > 0 && u < 1;
    if (!leafHinge.visible) return;
    leafHinge.rotation.y = -Math.PI * smooth(u);
    const arr = leafGeo.attributes.position.array;
    const curl = Math.sin(Math.PI * u) * 0.28;
    for (let i = 0; i < arr.length; i += 3) {
      const x = leafBase[i] / (W * 0.98) + 0.5; // 0 en el lomo, 1 en el borde
      arr[i + 2] = curl * Math.sin(Math.PI * x * 0.9) * x;
    }
    leafGeo.attributes.position.needsUpdate = true;
  }
  setBook(0);
  let turnAt = -10;

  // ---- letras, números y figuras de los libros
  const GLYPHS = ["A", "b", "ñ", "7", "½", "+", "=", "△", "○", "3×4", "¿?", "9", "%", "2"];
  const glyphs = [];
  GLYPHS.forEach((text, i) => {
    const mat = new SpriteMaterial({ map: glyphTexture(text), transparent: true, depthWrite: false });
    const s = new Sprite(mat);
    // Repartidos alrededor de Toco, sin taparle la cara.
    // En un óvalo alrededor de Toco que cabe en el lienzo; los de atrás, más hacia el centro.
    const ang = (i / GLYPHS.length) * TAU + 0.2;
    const z = -2.6 + hash(i + 9) * 3.2;
    const near = 1 + z / 9.5; // a más fondo, más cerca del centro para seguir en el encuadre
    const rad = (0.9 + hash(i + 5) * 0.12) * near;
    const base = new Vector3(Math.cos(ang) * 1.75 * rad, Math.sin(ang) * 2.15 * rad, z);
    const sc = 0.5 + hash(i + 13) * 0.35;
    s.scale.set(sc, sc, 1);
    s.position.copy(base);
    s.renderOrder = z < 0 ? 1 : 30;
    scene.add(s);
    glyphs.push({ s, base, sp: 5 + hash(i + 17) * 5, ph: hash(i + 19), red: i % 3 === 1 });
  });

  // ---- cielo: estrellas de noche, motas de día
  const sky = [];
  const dot = dotTexture();
  for (let g = 0; g < 2; g++) {
    const pos = [];
    for (let i = 0; i < 90; i++) {
      pos.push((hash(i * 3 + g * 500) * 2 - 1) * 9, (hash(i * 3 + 1 + g * 500) * 2 - 1) * 6, -4 - hash(i * 3 + 2 + g * 500) * 6);
    }
    const geo = new BufferGeometry();
    geo.setAttribute("position", new Float32BufferAttribute(pos, 3));
    const mat = new PointsMaterial({ size: 0.11, map: dot, transparent: true, depthWrite: false, sizeAttenuation: true });
    const p = new Points(geo, mat);
    p.renderOrder = 0;
    scene.add(p);
    sky.push(p);
  }

  // ---- estrellitas al tocar
  const burstTex = starTexture();
  const burst = [];
  for (let i = 0; i < 9; i++) {
    const s = new Sprite(new SpriteMaterial({ map: burstTex, transparent: true, depthWrite: false }));
    s.visible = false;
    s.renderOrder = 40;
    scene.add(s);
    burst.push({ s, v: new Vector3(), life: 0 });
  }

  // ---- colores del tema (se repiten al pulsar ☀️/🌙)
  let night = false;
  function applyTheme() {
    night = isDark();
    const blue = new Color(cssColor("--blue", "#0035ad"));
    const red = new Color(cssColor("--red", "#dc241f"));
    glyphs.forEach((g) => g.s.material.color.copy(g.red ? red : blue));
    const skyColor = night ? new Color("#ffffff") : new Color(cssColor("--blue", "#0035ad"));
    sky.forEach((p) => {
      p.material.color.copy(skyColor);
      p.material.size = night ? 0.11 : 0.16;
    });
    burst.forEach((b, i) => b.s.material.color.set(i % 3 === 0 ? red : new Color("#ffc93c")));
  }
  applyTheme();
  new MutationObserver(applyTheme).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  const mq = window.matchMedia("(prefers-color-scheme: dark)");
  if (mq.addEventListener) mq.addEventListener("change", applyTheme);

  // ---- puntero
  const pointer = { x: 0, y: 0, active: false, last: -10 };
  const view = { x: 0, y: 0 };
  let rect = stage.getBoundingClientRect();
  function onPointer(e) {
    rect = stage.getBoundingClientRect();
    pointer.x = Math.max(-1.6, Math.min(1.6, ((e.clientX - rect.left) / rect.width) * 2 - 1));
    pointer.y = Math.max(-1.6, Math.min(1.6, -(((e.clientY - rect.top) / rect.height) * 2 - 1)));
    pointer.active = true;
    pointer.last = performance.now() / 1000;
  }
  window.addEventListener("pointermove", onPointer, { passive: true });
  stage.addEventListener("pointerdown", (e) => { onPointer(e); if (clock() > 2.2) celebrate(); }, { passive: true });

  let happyAt = -10;
  function celebrate(from) {
    happyAt = clock();
    if (clock() > 3.2 && clock() - turnAt > 1.6) turnAt = clock();
    const head = new Vector3();
    if (from) head.copy(from); else parts.head.getWorldPosition(head);
    burst.forEach((b, i) => {
      const a = (i / burst.length) * TAU + Math.random() * 0.4;
      b.s.position.set(head.x + 0.2, head.y + 0.6, head.z + 0.3);
      b.v.set(Math.cos(a) * 1.6, Math.sin(a) * 1.4 + 1.2, (Math.random() - 0.5) * 0.6);
      b.life = 1;
      b.s.visible = true;
    });
  }

  // ---- tamaño
  let spreadX = 1;
  function resize() {
    const w = Math.max(1, stage.clientWidth), h = Math.max(1, stage.clientHeight);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    // En vertical, alejar un poco para que quepan Toco y las letras.
    camera.position.z = w / h < 0.9 ? 11 : 9.5;
    // En un lienzo apaisado (móvil), las letras se abren a los lados.
    spreadX = Math.max(1, Math.min(1.6, w / h / 0.8));
    camera.updateProjectionMatrix();
    rect = stage.getBoundingClientRect();
  }
  resize();
  new ResizeObserver(resize).observe(stage);

  // ---- bucle
  const t0 = performance.now();
  const clock = () => (performance.now() - t0) / 1000;
  const eyeWorld = new Vector3();
  let prev = 0;
  let introBurst = false;

  function frame() {
    const t = clock();
    const dt = Math.min(0.05, t - prev);
    prev = t;

    // Entrada: aparece el libro, se abre y Toco sale volando de él.
    const pop = easeOutBack(clamp01(t / 0.55));
    book.scale.setScalar(0.82 * Math.max(0.001, pop));
    setBook(smooth(clamp01((t - 0.45) / 0.8)));
    const rise = clamp01((t - 1.0) / 1.1);
    toco.position.y = -1.55 + (TOCO_Y + 1.55) * easeOutBack(rise);
    toco.scale.setScalar(TOCO_S * (0.15 + 0.85 * smooth(rise)));
    const tocoAlpha = clamp01((t - 1.0) / 0.3);
    tocoMats.forEach((m) => { m.opacity = tocoAlpha; });
    if (!introBurst && t > 1.15) {
      introBurst = true;
      const from = new Vector3();
      book.getWorldPosition(from);
      celebrate(from.add(new Vector3(0, 0.15, 0.3)));
      happyAt = -10; // las estrellas sí, el salto no (aún está saliendo)
    }
    book.position.y = -1.75 + 0.04 * wave(t, 5);
    // Luego, de vez en cuando, pasa una página.
    if (t > 3.2 && t - turnAt > 7) turnAt = t;
    setLeaf((t - turnAt) / 1.3);

    // Pose de reposo de la app, algo más viva para que se note en la web.
    const b = wave(t, 3);
    let sy = 1 + 0.012 * b;
    let dy = -1.4 * b;
    let head = 2.0 * wave(t, 6, 0.2) + 1.0 * wave(t, 4);
    let wing = 1.6 * b;
    let tail = 3.5 * wave(t, 4, 0.1);
    let lid = blink(t);

    // Mirada: hacia el puntero si se movió hace poco; si no, vaga como en la app.
    let gx, gy;
    const idle = t - (pointer.last - t0 / 1000) > 2.5 || !pointer.active;
    if (!idle) {
      eyeMesh.getWorldPosition(eyeWorld);
      eyeWorld.project(camera);
      let dx = (pointer.x - eyeWorld.x) * camera.aspect, dyy = -(pointer.y - eyeWorld.y);
      const len = Math.hypot(dx, dyy) || 1;
      const m = Math.min(1, len * 2.2);
      gx = (dx / len) * m;
      gy = (dyy / len) * m;
    } else {
      [gx, gy] = wander(t);
    }

    // Celebración al tocar (como "happy" en la app).
    const age = t - happyAt;
    const c = age < 0 || age > 1.8 ? 0 : age < 0.15 ? age / 0.15 : 1 - smooth((age - 0.15) / 1.65);
    if (c > 0) {
      const hop = Math.abs(wave(age, 0.5));
      dy -= 22 * c * hop;
      sy += 0.02 * c * (hop - 0.5);
      wing += 9 * c * (0.5 + 0.5 * wave(t, 0.3));
      tail += 5 * c * wave(t, 0.5);
      head -= 3 * c;
      lid *= 1 - c;
    }

    sy = 1 + clamp(sy - 1, 0.03);
    const sx = 1 - (sy - 1) * 0.5;
    body.scale.set(sx, sy, 1);
    body.position.y = fy - clamp(dy, 24) * PX;
    const rad = (deg, max) => (-clamp(deg, max) * Math.PI) / 180; // horario en pantalla
    parts.head.rotation.z = rad(head, MAX_DEG.head);
    parts.wing.rotation.z = rad(wing, c > 0 ? 16 : MAX_DEG.wing);
    parts.tail.rotation.z = rad(tail, MAX_DEG.tail);
    drawEye(clamp(gx, 1), clamp(gy, 1), Math.max(0, Math.min(1, lid)));

    // Paralaje: Toco gira un poco y la cámara se asoma hacia el puntero.
    const tx = idle ? 0.25 * wave(t, 14) : pointer.x;
    const ty = idle ? 0.15 * wave(t, 11) : pointer.y;
    const k = 1 - Math.pow(0.02, dt);
    view.x += (tx - view.x) * k;
    view.y += (ty - view.y) * k;
    rig.rotation.y = view.x * 0.32;
    rig.rotation.x = -view.y * 0.12;
    camera.position.x = view.x * 0.7;
    camera.position.y = view.y * 0.4;
    camera.lookAt(0, 0, 0);

    glyphs.forEach((g) => {
      const u = t / g.sp + g.ph;
      g.s.position.set(g.base.x * spreadX + 0.12 * Math.sin(TAU * u * 0.7), g.base.y + 0.22 * Math.sin(TAU * u), g.base.z);
      g.s.material.rotation = 0.25 * Math.sin(TAU * (u * 0.5 + 0.3));
      g.s.material.opacity = (night ? 0.75 : 0.55) * clamp01((t - 1.4) / 0.8);
    });

    sky[0].material.opacity = night ? 0.55 + 0.35 * Math.sin(t * 1.3) : 0.16;
    sky[1].material.opacity = night ? 0.55 + 0.35 * Math.sin(t * 1.1 + 2) : 0.12;
    sky.forEach((p, i) => { p.rotation.z = t * 0.004 * (i ? -1 : 1); });

    burst.forEach((bu) => {
      if (bu.life <= 0) return;
      bu.life -= dt / 1.1;
      if (bu.life <= 0) { bu.s.visible = false; return; }
      bu.v.y -= 2.6 * dt;
      bu.s.position.addScaledVector(bu.v, dt);
      const s = 0.32 * (0.6 + 0.4 * bu.life);
      bu.s.scale.set(s, s, 1);
      bu.s.material.opacity = Math.min(1, bu.life * 2);
    });

    renderer.render(scene, camera);
  }

  // Solo se anima con la portada a la vista y la pestaña abierta.
  let onScreen = true, raf = 0;
  const loop = () => { frame(); raf = requestAnimationFrame(loop); };
  const run = () => { if (!raf && onScreen && !document.hidden) { prev = clock(); raf = requestAnimationFrame(loop); } };
  const stop = () => { if (raf) cancelAnimationFrame(raf); raf = 0; };
  new IntersectionObserver((es) => { onScreen = es[0].isIntersecting; onScreen ? run() : stop(); }).observe(stage);
  document.addEventListener("visibilitychange", () => (document.hidden ? stop() : run()));

  canvas.addEventListener("webglcontextlost", (e) => {
    e.preventDefault();
    stop();
    stage.classList.remove("is-3d");
  });

  frame();
  stage.classList.add("is-3d");
  run();
}
