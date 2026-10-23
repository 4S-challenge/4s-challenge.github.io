import { generateSecret, judge, validateGuess, validateInitials, DIGITS } from './game';
import { VersusRoom } from './room';
import { isRoomCode, randomRoomCode } from './versus';

export { VersusRoom };

export interface Env {
  DB: D1Database;
  VERSUS: DurableObjectNamespace<VersusRoom>;
  ALLOWED_ORIGINS?: string;
}

/** 맞힌 뒤 이 시간 안에만 랭킹에 등록할 수 있다. */
const RANK_WINDOW_MS = 24 * 60 * 60 * 1000;
/** 이보다 오래된 게임 기록은 매일 정리한다. */
const GAME_RETENTION_MS = 2 * 24 * 60 * 60 * 1000;
const MAX_RANKING_LIMIT = 100;

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function isAllowedOrigin(origin: string, env: Env): boolean {
  const allowed = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return allowed.some(
    (entry) => origin === entry || (entry.endsWith('://localhost') && origin.startsWith(`${entry}:`)),
  );
}

function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (!origin || !isAllowedOrigin(origin, env)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...headers },
  });
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    const body = await request.json();
    if (body && typeof body === 'object' && !Array.isArray(body)) {
      return body as Record<string, unknown>;
    }
  } catch {
    // 아래에서 처리
  }
  throw new HttpError(400, '요청 형식이 올바르지 않아요');
}

function requireGameId(value: unknown): string {
  if (typeof value !== 'string' || !/^[0-9a-f-]{36}$/.test(value)) {
    throw new HttpError(400, '게임 정보가 올바르지 않아요');
  }
  return value;
}

interface GameRow {
  id: string;
  secret: string;
  started_at: number;
  tries: number;
  solved_at: number | null;
  ranked: number;
}

async function startSolo(env: Env): Promise<Response> {
  const id = crypto.randomUUID();
  const now = Date.now();
  await env.DB.prepare('INSERT INTO solo_games (id, secret, started_at) VALUES (?, ?, ?)')
    .bind(id, generateSecret(), now)
    .run();
  return json({ gameId: id, digits: DIGITS, startedAt: now }, 201);
}

async function guessSolo(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const gameId = requireGameId(body.gameId);
  const guessError = validateGuess(body.guess);
  if (guessError) throw new HttpError(400, guessError);
  const guess = body.guess as string;

  const game = await env.DB.prepare('SELECT * FROM solo_games WHERE id = ?')
    .bind(gameId)
    .first<GameRow>();
  if (!game) throw new HttpError(404, '게임을 찾을 수 없어요');
  if (game.solved_at !== null) throw new HttpError(409, '이미 끝난 게임이에요');

  const result = judge(game.secret, guess);
  const solved = result.strikes === DIGITS;
  const now = Date.now();

  // 동시에 들어온 요청이 있어도 한 번에 하나씩만 반영되도록 조건부로 갱신한다.
  const updated = await env.DB.prepare(
    `UPDATE solo_games
        SET tries = tries + 1,
            solved_at = CASE WHEN ?1 THEN ?2 ELSE NULL END
      WHERE id = ?3 AND solved_at IS NULL
  RETURNING tries, started_at, solved_at`,
  )
    .bind(solved ? 1 : 0, now, gameId)
    .first<{ tries: number; started_at: number; solved_at: number | null }>();
  if (!updated) throw new HttpError(409, '이미 끝난 게임이에요');

  return json({
    strikes: result.strikes,
    balls: result.balls,
    tries: updated.tries,
    solved,
    durationMs: solved ? now - updated.started_at : null,
  });
}

interface RankingRow {
  id: number;
  initials: string;
  tries: number;
  duration_ms: number;
  created_at: number;
}

function toEntry(row: RankingRow, rank: number) {
  return {
    id: row.id,
    rank,
    initials: row.initials,
    tries: row.tries,
    durationMs: row.duration_ms,
    createdAt: row.created_at,
  };
}

async function submitRanking(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const gameId = requireGameId(body.gameId);
  const initialsError = validateInitials(body.initials);
  if (initialsError) throw new HttpError(400, initialsError);
  const initials = body.initials as string;

  const game = await env.DB.prepare('SELECT * FROM solo_games WHERE id = ?')
    .bind(gameId)
    .first<GameRow>();
  if (!game) throw new HttpError(404, '게임을 찾을 수 없어요');
  if (game.solved_at === null) throw new HttpError(409, '아직 정답을 맞히지 않은 게임이에요');
  if (game.ranked) throw new HttpError(409, '이미 랭킹에 등록한 게임이에요');
  const now = Date.now();
  if (now - game.solved_at > RANK_WINDOW_MS) {
    throw new HttpError(409, '랭킹 등록 시간이 지났어요');
  }

  const durationMs = game.solved_at - game.started_at;
  const [marked, inserted] = await env.DB.batch([
    env.DB.prepare('UPDATE solo_games SET ranked = 1 WHERE id = ? AND ranked = 0').bind(gameId),
    env.DB.prepare(
      `INSERT INTO rankings (game_id, initials, tries, duration_ms, created_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(game_id) DO NOTHING
       RETURNING id, initials, tries, duration_ms, created_at`,
    ).bind(gameId, initials, game.tries, durationMs, now),
  ]);
  const row = (inserted.results as RankingRow[])[0];
  if (!marked.meta.changes || !row) {
    throw new HttpError(409, '이미 랭킹에 등록한 게임이에요');
  }

  const ahead = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM rankings
      WHERE tries < ?1
         OR (tries = ?1 AND duration_ms < ?2)
         OR (tries = ?1 AND duration_ms = ?2 AND created_at < ?3)
         OR (tries = ?1 AND duration_ms = ?2 AND created_at = ?3 AND id < ?4)`,
  )
    .bind(row.tries, row.duration_ms, row.created_at, row.id)
    .first<{ n: number }>();

  return json({ entry: toEntry(row, (ahead?.n ?? 0) + 1) }, 201);
}

async function listRankings(url: URL, env: Env): Promise<Response> {
  const requested = Number.parseInt(url.searchParams.get('limit') ?? '50', 10);
  const limit = Number.isFinite(requested)
    ? Math.min(Math.max(requested, 1), MAX_RANKING_LIMIT)
    : 50;
  const { results } = await env.DB.prepare(
    `SELECT id, initials, tries, duration_ms, created_at FROM rankings
      ORDER BY tries ASC, duration_ms ASC, created_at ASC, id ASC
      LIMIT ?`,
  )
    .bind(limit)
    .all<RankingRow>();
  return json({ entries: results.map((row, i) => toEntry(row, i + 1)) });
}

/** 새 대결방을 만들고 방 코드를 돌려준다. */
async function createVersusRoom(env: Env): Promise<Response> {
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = randomRoomCode();
    const stub = env.VERSUS.get(env.VERSUS.idFromName(code));
    const res = await stub.fetch(`https://room/init?code=${code}`, { method: 'POST' });
    if (res.status === 201) return json({ code }, 201);
  }
  throw new HttpError(503, '방을 만들지 못했어요. 잠시 후 다시 시도해 주세요');
}

/** 들어가기 전에 방 요약(대결 중인지, 누가 하는지, 관전자 수)을 본다. */
async function peekVersusRoom(env: Env, code: string): Promise<Response> {
  if (!isRoomCode(code)) throw new HttpError(400, '방 코드가 올바르지 않아요');
  const stub = env.VERSUS.get(env.VERSUS.idFromName(code));
  const res = await stub.fetch('https://room/peek');
  return json(await res.json(), res.status);
}

/** 대결방 WebSocket 연결을 해당 방(Durable Object)으로 넘긴다. */
function connectVersusRoom(request: Request, env: Env, code: string, url: URL): Promise<Response> | Response {
  const origin = request.headers.get('Origin');
  if (origin && !isAllowedOrigin(origin, env)) {
    return new Response('forbidden', { status: 403 });
  }
  if (!isRoomCode(code)) throw new HttpError(400, '방 코드가 올바르지 않아요');
  const stub = env.VERSUS.get(env.VERSUS.idFromName(code));
  return stub.fetch(`https://room/ws${url.search}`, request);
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const key = `${request.method} ${url.pathname.replace(/\/+$/, '')}`;
  switch (key) {
    case 'GET /api/health':
      return json({ ok: true });
    case 'POST /api/solo/start':
      return startSolo(env);
    case 'POST /api/solo/guess':
      return guessSolo(request, env);
    case 'GET /api/rankings':
      return listRankings(url, env);
    case 'POST /api/rankings':
      return submitRanking(request, env);
    case 'POST /api/versus/rooms':
      return createVersusRoom(env);
    default: {
      const ws = /^GET \/api\/versus\/rooms\/([A-Za-z0-9]+)\/ws$/.exec(key);
      if (ws) return connectVersusRoom(request, env, ws[1].toUpperCase(), url);
      const room = /^GET \/api\/versus\/rooms\/([A-Za-z0-9]+)$/.exec(key);
      if (room) return peekVersusRoom(env, room[1].toUpperCase());
      throw new HttpError(404, '없는 주소예요');
    }
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const cors = corsHeaders(request, env);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }
    let response: Response;
    try {
      response = await route(request, env);
    } catch (err) {
      if (err instanceof HttpError) {
        response = json({ error: err.message }, err.status);
      } else {
        console.error(err);
        response = json({ error: '잠시 후 다시 시도해 주세요' }, 500);
      }
    }
    // WebSocket 연결 응답(101)은 그대로 돌려준다.
    if (response.status === 101 || response.webSocket) return response;
    for (const [k, v] of Object.entries(cors)) response.headers.set(k, v);
    return response;
  },

  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    await env.DB.prepare('DELETE FROM solo_games WHERE started_at < ?')
      .bind(Date.now() - GAME_RETENTION_MS)
      .run();
  },
} satisfies ExportedHandler<Env>;
