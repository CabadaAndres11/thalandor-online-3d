// Smoke test against a running server: node test/smoke.mjs [ws://127.0.0.1:8787]
// Host opens a room, a guest joins, they relay an offer and an answer, errors for
// bad/unknown codes, and the guest is told when the host leaves.
const base = process.argv[2] ?? "ws://127.0.0.1:8787";

function open(path) {
  const ws = new WebSocket(base + path);
  const queue = [];
  const waiters = [];
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    const w = waiters.shift();
    if (w) w(msg);
    else queue.push(msg);
  };
  ws.next = () =>
    new Promise((resolve, reject) => {
      if (queue.length) return resolve(queue.shift());
      const t = setTimeout(() => reject(new Error("timeout on " + path)), 5000);
      waiters.push((m) => (clearTimeout(t), resolve(m)));
    });
  return new Promise((resolve, reject) => {
    ws.onopen = () => resolve(ws);
    ws.onerror = () => reject(new Error("cannot open " + path));
  });
}

function check(cond, what) {
  if (!cond) throw new Error("FAILED: " + what);
  console.log("ok -", what);
}

const host = await open("/host");
const room = await host.next();
check(room.type === "room" && /^[2-9A-Z]{4}-[2-9A-Z]{4}$/.test(room.code) && room.id === 1, "host gets a room code");

const guest = await open("/join/" + room.code.toLowerCase().replace("-", ""));
const joined = await guest.next();
check(joined.type === "joined" && joined.id === 2, "guest joins as id 2 (code is case/dash insensitive)");
const peer = await host.next();
check(peer.type === "peer" && peer.id === 2, "host is told about the guest");

host.send(JSON.stringify({ type: "offer", to: 2, sdp: "v=0 offer" }));
const offer = await guest.next();
check(offer.type === "offer" && offer.from === 1 && offer.sdp === "v=0 offer", "offer relayed to guest");
guest.send(JSON.stringify({ type: "answer", to: 1, sdp: "v=0 answer" }));
const answer = await host.next();
check(answer.type === "answer" && answer.from === 2, "answer relayed to host");

const bad = await open("/join/AAAA-AAAA");
check((await bad.next()).reason === "bad_code", "bad check symbol rejected");
const other = await open("/join/2222-2222"); // valid check symbol, no such room
check((await other.next()).reason === "no_room", "unknown room rejected");

host.close();
const left = await guest.next();
check(left.type === "host_left", "guest told the host left");
console.log("ALL OK");
process.exit(0);
