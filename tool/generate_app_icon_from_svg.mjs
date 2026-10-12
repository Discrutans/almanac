import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";
import { PNG } from "pngjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const SVG_PATH = join(ROOT, "assets", "branding", "app_icon_source.svg");
const OUT_DIR = join(ROOT, "assets", "branding");

const SIZE = 1024;

function renderSvg(svg, width, height) {
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: width },
    background: "transparent",
  });
  return PNG.sync.read(resvg.render().asPng());
}

function fitToSquare(source, size) {
  if (source.width === size && source.height === size) {
    return source;
  }

  const canvas = new PNG({ width: size, height: size, fill: true });
  const scale = Math.min(size / source.width, size / source.height);
  const drawW = Math.round(source.width * scale);
  const drawH = Math.round(source.height * scale);
  const offsetX = Math.floor((size - drawW) / 2);
  const offsetY = Math.floor((size - drawH) / 2);

  for (let y = 0; y < drawH; y += 1) {
    const srcY = Math.min(Math.floor(y / scale), source.height - 1);
    for (let x = 0; x < drawW; x += 1) {
      const srcX = Math.min(Math.floor(x / scale), source.width - 1);
      const srcIdx = (source.width * srcY + srcX) << 2;
      const dstIdx = (size * (offsetY + y) + (offsetX + x)) << 2;
      canvas.data[dstIdx] = source.data[srcIdx];
      canvas.data[dstIdx + 1] = source.data[srcIdx + 1];
      canvas.data[dstIdx + 2] = source.data[srcIdx + 2];
      canvas.data[dstIdx + 3] = source.data[srcIdx + 3];
    }
  }

  return canvas;
}

function glyphForeground(fullIcon, insetPx) {
  const canvas = new PNG({ width: SIZE, height: SIZE, fill: true });
  const inner = SIZE - insetPx * 2;
  const scale = inner / SIZE;
  const drawW = Math.round(SIZE * scale);
  const drawH = Math.round(SIZE * scale);
  const offsetX = Math.floor((SIZE - drawW) / 2);
  const offsetY = Math.floor((SIZE - drawH) / 2);

  for (let y = 0; y < drawH; y += 1) {
    const srcY = Math.min(Math.floor(y / scale), fullIcon.height - 1);
    for (let x = 0; x < drawW; x += 1) {
      const srcX = Math.min(Math.floor(x / scale), fullIcon.width - 1);
      const srcIdx = (fullIcon.width * srcY + srcX) << 2;
      const dstIdx = (SIZE * (offsetY + y) + (offsetX + x)) << 2;
      canvas.data[dstIdx] = fullIcon.data[srcIdx];
      canvas.data[dstIdx + 1] = fullIcon.data[srcIdx + 1];
      canvas.data[dstIdx + 2] = fullIcon.data[srcIdx + 2];
      canvas.data[dstIdx + 3] = fullIcon.data[srcIdx + 3];
    }
  }

  return canvas;
}

const svg = readFileSync(SVG_PATH, "utf8");
const rendered = fitToSquare(renderSvg(svg, SIZE, SIZE), SIZE);

mkdirSync(OUT_DIR, { recursive: true });

writeFileSync(join(OUT_DIR, "app_icon.png"), PNG.sync.write(rendered));
writeFileSync(
  join(OUT_DIR, "app_icon_foreground.png"),
  PNG.sync.write(glyphForeground(rendered, 96)),
);

console.log(`Wrote ${join(OUT_DIR, "app_icon.png")}`);
console.log(`Wrote ${join(OUT_DIR, "app_icon_foreground.png")}`);
