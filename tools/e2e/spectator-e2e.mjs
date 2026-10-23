// 실제(또는 로컬) 서버에 선수 두 명과 관전자가 접속해 관전 흐름을 확인한다. BASE=서버 주소
const BASE = process.env.BASE ?? 'http://127.0.0.1:8787';
const WS_BASE = BASE.replace(/^http/, 'ws');
let fails = 0;
const check = (name, cond, info) => {
  console.log((cond ? 'PASS ' : 'FAIL ') + name + (cond ? '' : `  -> ${JSON.stringify(info)}`));
  if (!cond) fails++;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class Client {
  constructor(code, name, playerId, watch) {
    const q = new URLSearchParams({ name });
    if (playerId) q.set('playerId', playerId);
    if (watch) q.set('watch', '1');
    this.messages = [];
    this.waiters = [];
    this.ws = new WebSocket(`${WS_BASE}/api/versus/rooms/${code}/ws?${q}`);
    this.ws.addEventListener('message', (ev) => {
      if (ev.data === 'pong') { this.pong = true; return; }
      const m = JSON.parse(ev.data);
      if (m.type === 'welcome') this.playerId = m.playerId;
      if (m.type === 'state') this.state = m;
      const w = this.waiters.find((x) => x.pred(m));
      if (w) { this.waiters.splice(this.waiters.indexOf(w), 1); w.resolve(m); } else this.messages.push(m);
    });
    this.closed = new Promise((r) => this.ws.addEventListener('close', (ev) => r(ev.code)));
    this.opened = new Promise((r, j) => { this.ws.addEventListener('open', r); this.ws.addEventListener('error', j); });
  }
  wait(pred, ms = 5000) {
    const hit = this.messages.find(pred);
    if (hit) { this.messages = this.messages.filter((m) => m !== hit); return Promise.resolve(hit); }
    return new Promise((resolve, reject) => {
      const w = { pred, resolve };
      this.waiters.push(w);
      setTimeout(() => reject(new Error('timeout waiting')), ms);
    });
  }
  waitState(pred, ms) { return this.wait((m) => m.type === 'state' && pred(m), ms); }
  send(obj) { this.ws.send(JSON.stringify(obj)); }
  clear() { this.messages = []; }
}

async function createRoom() {
  const res = await fetch(`${BASE}/api/versus/rooms`, { method: 'POST' });
  return { status: res.status, body: await res.json() };
}


for (let i = 0; i < 60; i++) {
  try { if ((await fetch(`${BASE}/api/health`)).ok) break; } catch { await sleep(1000); }
}
const { body: { code } } = await createRoom();
const peek = async () => { const r = await fetch(`${BASE}/api/versus/rooms/${code}`); return { status: r.status, body: await r.json() }; };
const missing = await fetch(`${BASE}/api/versus/rooms/ZZZZ`);
check('peek missing room 404', missing.status === 404, missing.status);

const a = new Client(code, 'AAA'); await a.opened; await a.wait((m) => m.type === 'welcome');
let p = await peek();
check('peek: one player, not full', p.status === 200 && p.body.full === false && p.body.players.join() === 'AAA', p);
const b = new Client(code, 'BBB'); await b.opened; await b.waitState((s) => s.phase === 'setting');
p = await peek();
check('peek: full', p.body.full === true && p.body.players.join() === 'AAA,BBB' && p.body.spectators === 0, p);

const rej = new Client(code, 'CCC');
const re = await rej.wait((m) => m.type === 'error');
check('no watch flag rejected', re.fatal === true, re);

const c = new Client(code, 'CCC', null, true); await c.opened;
const cw = await c.wait((m) => m.type === 'welcome');
let sc = await c.waitState((s) => s.role === 'spectator');
check('spectator state', sc.me.name === 'AAA' && sc.opponent.name === 'BBB' && sc.spectators.length === 1 && sc.spectators[0].me === true, sc);
let sa = await a.waitState((s) => s.spectators.length === 1);
check('player sees spectator', sa.spectators[0].name === 'CCC' && !sa.spectators[0].me && sa.role === 'player', sa.spectators);
p = await peek();
check('peek: 1 spectator', p.body.spectators === 1, p);

a.send({ type: 'setSecret', secret: '1234' });
b.send({ type: 'setSecret', secret: '5678' });
sc = await c.waitState((s) => s.phase === 'playing');
check('spectator: secrets hidden', sc.me.secret === null && sc.opponent.secret === null && !JSON.stringify(sc).includes('1234') && !JSON.stringify(sc).includes('5678'), sc);
c.send({ type: 'guess', guess: '5678' });
const ce = await c.wait((m) => m.type === 'error');
check('spectator cannot guess', !ce.fatal, ce);

// reconnect
c.ws.close();
await sleep(400);
sa = await a.waitState((s) => s.spectators.length === 0);
check('spectator gone from list on disconnect', true);
const c2 = new Client(code, 'CCC', cw.playerId, true); await c2.opened;
const c2w = await c2.wait((m) => m.type === 'welcome');
check('spectator reconnect keeps id', c2w.playerId === cw.playerId, c2w);
await a.waitState((s) => s.spectators.length === 1);

const first = sc.turn === 0 ? a : b;
const target = first === a ? '5678' : '1234';
first.send({ type: 'guess', guess: target });
const done = await c2.waitState((s) => s.phase === 'finished');
check('spectator sees both secrets at end', done.me.secret === '1234' && done.opponent.secret === '5678' && done.winner === sc.turn, done);

c2.send({ type: 'leave' });
check('spectator leave closes', (await c2.closed) === 1000);
sa = await a.waitState((s) => s.phase === 'finished' && s.spectators.length === 0);
check('player sees spectator left', true);

a.ws.close(); b.ws.close();
console.log(fails ? `${fails} FAILED` : 'ALL PASS');
process.exit(fails ? 1 : 0);
