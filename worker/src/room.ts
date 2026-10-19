import { DurableObject } from 'cloudflare:workers';
import type { Env } from './index';
import {
  RoomError,
  type RoomState,
  createRoom,
  disconnect,
  expireTurn,
  guess,
  join,
  leave,
  requestRematch,
  setSecret,
  viewFor,
} from './versus';

/** 아무도 접속해 있지 않은 방은 이 시간 뒤 지운다. */
const IDLE_MS = 15 * 60 * 1000;
/** 사람이 접속해 있어도 이 시간 넘게 아무 행동이 없으면 지운다. */
const ABANDON_MS = 2 * 60 * 60 * 1000;

interface Attachment {
  playerId: string;
}

/** 대결방 하나 = Durable Object 하나. 방 코드로 찾는다. */
export class VersusRoom extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // 접속 유지용 ping은 객체를 깨우지 않고 바로 응답한다.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  private async load(): Promise<RoomState | undefined> {
    return this.ctx.storage.get<RoomState>('state');
  }

  private async save(state: RoomState): Promise<void> {
    await this.ctx.storage.put('state', state);
    // 대결 중에는 차례 마감 시각에, 그 외에는 정리 여부를 보러 깨운다.
    const next =
      state.phase === 'playing' && state.turnDeadline !== null
        ? state.turnDeadline
        : Math.max(state.updatedAt + IDLE_MS, Date.now() + 60_000);
    await this.ctx.storage.setAlarm(next);
  }

  private broadcast(state: RoomState): void {
    const now = Date.now();
    for (const ws of this.ctx.getWebSockets()) {
      const att = ws.deserializeAttachment() as Attachment | null;
      if (!att) continue;
      try {
        ws.send(JSON.stringify(viewFor(state, att.playerId, now)));
      } catch {
        // 이미 닫힌 연결
      }
    }
  }

  private static sendError(ws: WebSocket, message: string, fatal = false): void {
    try {
      ws.send(JSON.stringify({ type: 'error', message, fatal }));
    } catch {
      // 무시
    }
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/init') {
      const code = url.searchParams.get('code') ?? '';
      if (await this.load()) return new Response('exists', { status: 409 });
      await this.save(createRoom(code, Date.now()));
      return new Response('created', { status: 201 });
    }

    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
        return new Response('WebSocket 연결이 필요해요', { status: 426 });
      }
      const pair = new WebSocketPair();
      const [client, server] = [pair[0], pair[1]];

      const state = await this.load();
      if (!state) {
        server.accept();
        VersusRoom.sendError(server, '없는 방이에요. 코드를 확인해 주세요', true);
        server.close(4004, 'not found');
        return new Response(null, { status: 101, webSocket: client });
      }

      let playerId: string;
      try {
        playerId = join(
          state,
          {
            playerId: url.searchParams.get('playerId'),
            name: url.searchParams.get('name') ?? '',
            newId: crypto.randomUUID(),
            firstSeat: crypto.getRandomValues(new Uint8Array(1))[0] % 2,
          },
          Date.now(),
        );
      } catch (err) {
        server.accept();
        VersusRoom.sendError(server, err instanceof RoomError ? err.message : '들어갈 수 없는 방이에요', true);
        server.close(4009, 'rejected');
        return new Response(null, { status: 101, webSocket: client });
      }

      // 같은 참가자의 예전 연결(재접속 전 연결)은 닫는다.
      for (const old of this.ctx.getWebSockets(playerId)) {
        try {
          old.close(4000, 'replaced');
        } catch {
          // 무시
        }
      }

      this.ctx.acceptWebSocket(server, [playerId]);
      server.serializeAttachment({ playerId } satisfies Attachment);
      server.send(JSON.stringify({ type: 'welcome', playerId }));

      await this.save(state);
      this.broadcast(state);
      return new Response(null, { status: 101, webSocket: client });
    }

    return new Response('not found', { status: 404 });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const att = ws.deserializeAttachment() as Attachment | null;
    if (!att || typeof message !== 'string') return;

    let data: { type?: unknown; secret?: unknown; guess?: unknown };
    try {
      data = JSON.parse(message);
    } catch {
      return;
    }

    const state = await this.load();
    if (!state) {
      VersusRoom.sendError(ws, '방이 사라졌어요', true);
      ws.close(4004, 'gone');
      return;
    }

    const now = Date.now();
    try {
      // 차례 시간이 지난 상태에서 들어온 요청은 먼저 시간 초과를 반영한다.
      expireTurn(state, now);
      switch (data.type) {
        case 'setSecret':
          setSecret(state, att.playerId, data.secret, now);
          break;
        case 'guess':
          guess(state, att.playerId, data.guess, now);
          break;
        case 'rematch':
          requestRematch(state, att.playerId, now);
          break;
        case 'leave':
          leave(state, att.playerId, now);
          break;
        default:
          return;
      }
    } catch (err) {
      if (err instanceof RoomError) {
        VersusRoom.sendError(ws, err.message);
        // 상태가 바뀌었을 수 있으니(시간 초과) 최신 상태도 보낸다.
        await this.save(state);
        this.broadcast(state);
        return;
      }
      throw err;
    }

    await this.save(state);
    this.broadcast(state);
    if (data.type === 'leave') {
      try {
        ws.close(1000, 'left');
      } catch {
        // 무시
      }
    }
  }

  private async onSocketGone(ws: WebSocket): Promise<void> {
    const att = ws.deserializeAttachment() as Attachment | null;
    if (!att) return;
    const stillOpen = this.ctx
      .getWebSockets(att.playerId)
      .some((s) => s !== ws && s.readyState === WebSocket.OPEN);
    if (stillOpen) return;

    const state = await this.load();
    if (!state) return;
    disconnect(state, att.playerId);
    // 대기 중에 방장이 나가면 방을 비운다.
    if (state.phase === 'waiting') {
      state.players = state.players.filter((p) => p.id !== att.playerId);
    }
    await this.save(state);
    this.broadcast(state);
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    await this.onSocketGone(ws);
    try {
      ws.close(code === 1005 ? 1000 : code, 'closed');
    } catch {
      // 이미 닫힘
    }
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.onSocketGone(ws);
  }

  async alarm(): Promise<void> {
    const state = await this.load();
    if (!state) return;
    const now = Date.now();
    const sockets = this.ctx.getWebSockets().filter((s) => s.readyState === WebSocket.OPEN);

    const idle = sockets.length === 0 && now - state.updatedAt >= IDLE_MS;
    const abandoned = now - state.updatedAt >= ABANDON_MS;
    if (idle || abandoned) {
      for (const ws of sockets) {
        VersusRoom.sendError(ws, '오래 움직임이 없어 방이 닫혔어요', true);
        try {
          ws.close(4010, 'expired');
        } catch {
          // 무시
        }
      }
      await this.ctx.storage.deleteAll();
      return;
    }

    if (expireTurn(state, now)) this.broadcast(state);
    await this.save(state);
  }
}
