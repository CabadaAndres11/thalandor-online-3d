// Thalandor Online signaling server (Cloudflare Workers + Durable Objects).
// Only introduces players: WebRTC offers, answers and ICE candidates are relayed
// between the host (id 1) and its guests; game traffic never passes through here.
//
//   GET /host         (WebSocket) -> {"type":"room","code":"ABCD-EFGH","id":1}
//   GET /join/<code>  (WebSocket) -> {"type":"joined","id":n}; the host gets {"type":"peer","id":n}
//   {"type":"offer"|"answer"|"candidate","to":id,...}  -> relayed with "from"
//   Errors: {"type":"error","reason":"no_room"|"full"|"bad_code"}
//   Host leaves -> guests get {"type":"host_left"}; guest leaves -> host gets {"type":"peer_left","id":n}

import { DurableObject } from "cloudflare:workers";

const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"; // same as net/group_code.gd
const MAX_PLAYERS = 4;
const ROOM_TTL_MS = 12 * 60 * 60 * 1000;
const RELAYED = new Set(["offer", "answer", "candidate"]);

// Same encoding as GroupCode.encode: a 32-bit value in 7 base-31 symbols + check symbol,
// so the game validates WebRTC codes exactly like ENet ones.
export function newCode() {
  let value = crypto.getRandomValues(new Uint32Array(1))[0];
  let digits = "";
  let sum = 0;
  for (let i = 0; i < 7; i++) {
    const d = value % 31;
    value = Math.floor(value / 31);
    digits = ALPHABET[d] + digits;
    sum += d;
  }
  const raw = digits + ALPHABET[sum % 31];
  return raw.slice(0, 4) + "-" + raw.slice(4);
}

export function normalizeCode(code) {
  const raw = decodeURIComponent(code).toUpperCase().replace(/[\s-]/g, "");
  if (raw.length !== 8) return null;
  let value = 0;
  let sum = 0;
  for (let i = 0; i < 7; i++) {
    const d = ALPHABET.indexOf(raw[i]);
    if (d < 0) return null;
    value = value * 31 + d;
    sum += d;
  }
  if (ALPHABET.indexOf(raw[7]) !== sum % 31 || value > 0xffffffff) return null;
  return raw.slice(0, 4) + "-" + raw.slice(4);
}

export default {
  async fetch(request, env) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Thalandor Online signaling\n", { status: 200 });
    }
    const path = new URL(request.url).pathname;
    let code;
    let role;
    if (path === "/host") {
      code = newCode();
      role = "host";
    } else if (path.startsWith("/join/")) {
      code = normalizeCode(path.slice(6));
      role = "guest";
      if (code === null) return rejectSocket("bad_code");
    } else {
      return new Response("Not found\n", { status: 404 });
    }
    const room = env.ROOMS.get(env.ROOMS.idFromName(code));
    return room.fetch(`https://room/${role}/${code}`, { headers: request.headers });
  },
};

function rejectSocket(reason) {
  const { 0: client, 1: server } = new WebSocketPair();
  server.accept();
  server.send(JSON.stringify({ type: "error", reason }));
  server.close(1000, reason);
  return new Response(null, { status: 101, webSocket: client });
}

export class Room extends DurableObject {
  async fetch(request) {
    const [, role, code] = new URL(request.url).pathname.split("/");
    if (role !== "host" && role !== "guest") return new Response("Bad request\n", { status: 400 });
    const { 0: client, 1: server } = new WebSocketPair();
    const sockets = this.ctx.getWebSockets();
    const host = sockets.find((ws) => ws.deserializeAttachment()?.id === 1);
    let error = null;
    if (role === "host" && sockets.length > 0) error = "full"; // code collision: retry
    if (role === "guest" && !host) error = "no_room";
    if (role === "guest" && host && sockets.length >= MAX_PLAYERS) error = "full";
    if (error) {
      server.accept();
      server.send(JSON.stringify({ type: "error", reason: error }));
      server.close(1000, error);
      return new Response(null, { status: 101, webSocket: client });
    }
    const id = role === "host" ? 1 : this.nextId(sockets);
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ id });
    if (role === "host") {
      server.send(JSON.stringify({ type: "room", code, id }));
      await this.ctx.storage.setAlarm(Date.now() + ROOM_TTL_MS);
    } else {
      server.send(JSON.stringify({ type: "joined", id }));
      host.send(JSON.stringify({ type: "peer", id }));
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  nextId(sockets) {
    const used = new Set(sockets.map((ws) => ws.deserializeAttachment()?.id));
    let id = 2;
    while (used.has(id)) id++;
    return id;
  }

  find(id) {
    return this.ctx.getWebSockets().find((ws) => ws.deserializeAttachment()?.id === id);
  }

  async webSocketMessage(ws, text) {
    let msg;
    try {
      msg = JSON.parse(text);
    } catch {
      return;
    }
    if (!RELAYED.has(msg.type)) return;
    const from = ws.deserializeAttachment()?.id;
    // Star topology: guests only talk to the host.
    if (from !== 1 && msg.to !== 1) return;
    const target = this.find(msg.to);
    if (target) target.send(JSON.stringify({ ...msg, from }));
  }

  async webSocketClose(ws) {
    this.left(ws);
  }

  async webSocketError(ws) {
    this.left(ws);
  }

  left(ws) {
    const id = ws.deserializeAttachment()?.id;
    for (const other of this.ctx.getWebSockets()) {
      if (other === ws) continue;
      if (id === 1) {
        other.send(JSON.stringify({ type: "host_left" }));
        other.close(1000, "host_left");
      } else if (other.deserializeAttachment()?.id === 1) {
        other.send(JSON.stringify({ type: "peer_left", id }));
      }
    }
  }

  async alarm() {
    for (const ws of this.ctx.getWebSockets()) ws.close(1000, "expired");
  }
}
