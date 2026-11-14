// Minimal PNG reader/writer for the art scripts (Node built-ins only).
// read(): 8-bit grayscale, gray+alpha, RGB, RGBA or palette (with tRNS), non-interlaced.
// Returns { width, height, data } with data = Uint8Array RGBA. write() saves RGBA.
import fs from "node:fs";
import zlib from "node:zlib";

const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const CHANNELS = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };

export function read(path) {
  const buf = fs.readFileSync(path);
  if (!buf.subarray(0, 8).equals(SIGNATURE)) throw new Error(`${path}: not a PNG`);
  let pos = 8;
  let width = 0, height = 0, depth = 0, type = 0, interlace = 0;
  let palette = null, trns = null;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const kind = buf.toString("ascii", pos + 4, pos + 8);
    const body = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === "IHDR") {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      depth = body[8];
      type = body[9];
      interlace = body[12];
    } else if (kind === "PLTE") palette = body;
    else if (kind === "tRNS") trns = body;
    else if (kind === "IDAT") idat.push(body);
    else if (kind === "IEND") break;
    pos += 12 + len;
  }
  if (depth !== 8 || interlace !== 0 || !(type in CHANNELS)) {
    throw new Error(`${path}: unsupported PNG (depth ${depth}, type ${type}, interlace ${interlace})`);
  }
  const bpp = CHANNELS[type];
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * bpp;
  const pixels = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const out = pixels.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : null;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[x - bpp] : 0;
      const b = prev ? prev[x] : 0;
      const c = prev && x >= bpp ? prev[x - bpp] : 0;
      let v = line[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      out[x] = v & 255;
    }
  }
  const data = new Uint8Array(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const s = i * bpp, d = i * 4;
    if (type === 3) {
      const p = pixels[s];
      data[d] = palette[p * 3]; data[d + 1] = palette[p * 3 + 1]; data[d + 2] = palette[p * 3 + 2];
      data[d + 3] = trns && p < trns.length ? trns[p] : 255;
    } else if (type === 0 || type === 4) {
      data[d] = data[d + 1] = data[d + 2] = pixels[s];
      data[d + 3] = type === 4 ? pixels[s + 1] : 255;
    } else {
      data[d] = pixels[s]; data[d + 1] = pixels[s + 1]; data[d + 2] = pixels[s + 2];
      data[d + 3] = type === 6 ? pixels[s + 3] : 255;
    }
  }
  return { width, height, data };
}

export function create(width, height) {
  return { width, height, data: new Uint8Array(width * height * 4) };
}

export function write(path, img) {
  const stride = img.width * 4;
  const raw = Buffer.alloc((stride + 1) * img.height);
  for (let y = 0; y < img.height; y++) {
    raw[y * (stride + 1)] = 0;
    Buffer.from(img.data.buffer, img.data.byteOffset + y * stride, stride).copy(raw, y * (stride + 1) + 1);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.width, 0);
  ihdr.writeUInt32BE(img.height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const out = Buffer.concat([
    SIGNATURE,
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.writeFileSync(path, out);
}

function chunk(kind, body) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(body.length);
  const kb = Buffer.from(kind, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([kb, body])) >>> 0);
  return Buffer.concat([len, kb, body, crc]);
}

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 255] ^ (c >>> 8);
  return c ^ 0xffffffff;
}

// Pixel helpers.
export function get(img, x, y) {
  const i = (y * img.width + x) * 4;
  return [img.data[i], img.data[i + 1], img.data[i + 2], img.data[i + 3]];
}

export function set(img, x, y, rgba) {
  const i = (y * img.width + x) * 4;
  img.data[i] = rgba[0]; img.data[i + 1] = rgba[1]; img.data[i + 2] = rgba[2]; img.data[i + 3] = rgba[3];
}

export function blit(dst, src, sx, sy, w, h, dx, dy) {
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) set(dst, dx + x, dy + y, get(src, sx + x, sy + y));
}
