// 친구와 대결: 방 한 개의 규칙. 저장·네트워크와 상관없는 순수 로직이라 단위 테스트한다.
//
// 흐름: waiting(1명) → setting(2명, 각자 상대가 맞힐 비밀 숫자 정하기)
//       → playing(번갈아 던지기, 차례당 30초) → finished(4S 또는 기권)
//       → 둘 다 '한 판 더'를 누르면 다시 setting, 선공은 번갈아 바뀐다.

import { DIGITS, judge, validateGuess, validateInitials } from './game';

export const TURN_MS = 30_000;
export const ROOM_CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const ROOM_CODE_LENGTH = 4;
const MAX_GUESSES_PER_PLAYER = 200;

export type Phase = 'waiting' | 'setting' | 'playing' | 'finished';
export type EndReason = 'solved' | 'forfeit';

export interface GuessEntry {
  guess: string;
  strikes: number;
  balls: number;
}

export interface Player {
  id: string;
  name: string;
  secret: string | null;
  /** 이 플레이어가 상대 숫자를 맞히려고 던진 기록. */
  guesses: GuessEntry[];
  connected: boolean;
  left: boolean;
  rematch: boolean;
}

export interface RoomEvent {
  type: 'timeout';
  seat: number;
  at: number;
}

export interface RoomState {
  code: string;
  createdAt: number;
  updatedAt: number;
  phase: Phase;
  players: Player[];
  round: number;
  firstSeat: number;
  turn: number;
  turnDeadline: number | null;
  winner: number | null;
  endReason: EndReason | null;
  lastEvent: RoomEvent | null;
}

export class RoomError extends Error {}

export function isRoomCode(value: string): boolean {
  if (value.length !== ROOM_CODE_LENGTH) return false;
  for (const ch of value) if (!ROOM_CODE_CHARS.includes(ch)) return false;
  return true;
}

export function randomRoomCode(): string {
  const buf = new Uint32Array(ROOM_CODE_LENGTH);
  crypto.getRandomValues(buf);
  return Array.from(buf, (n) => ROOM_CODE_CHARS[n % ROOM_CODE_CHARS.length]).join('');
}

export function createRoom(code: string, now: number): RoomState {
  return {
    code,
    createdAt: now,
    updatedAt: now,
    phase: 'waiting',
    players: [],
    round: 1,
    firstSeat: 0,
    turn: 0,
    turnDeadline: null,
    winner: null,
    endReason: null,
    lastEvent: null,
  };
}

function seatOf(state: RoomState, playerId: string): number {
  const seat = state.players.findIndex((p) => p.id === playerId);
  if (seat < 0) throw new RoomError('이 방의 참가자가 아니에요');
  return seat;
}

function other(seat: number): number {
  return seat === 0 ? 1 : 0;
}

/**
 * 입장. [playerId]가 이미 이 방 참가자면 재접속으로 처리한다.
 * 새 참가자면 [newId]로 등록한다. 돌려주는 값은 이 연결의 playerId.
 */
export function join(
  state: RoomState,
  args: { playerId?: string | null; name: string; newId: string; firstSeat: number },
  now: number,
): string {
  const existing = args.playerId ? state.players.find((p) => p.id === args.playerId) : undefined;
  if (existing) {
    if (existing.left) throw new RoomError('이미 나간 방이에요');
    existing.connected = true;
    state.updatedAt = now;
    return existing.id;
  }

  const nameError = validateInitials(args.name);
  if (nameError) throw new RoomError(nameError);
  if (state.phase !== 'waiting' || state.players.length >= 2) {
    throw new RoomError('이미 대결이 시작된 방이에요');
  }

  state.players.push({
    id: args.newId,
    name: args.name,
    secret: null,
    guesses: [],
    connected: true,
    left: false,
    rematch: false,
  });
  if (state.players.length === 2) {
    state.phase = 'setting';
    state.firstSeat = args.firstSeat === 1 ? 1 : 0;
  }
  state.updatedAt = now;
  return args.newId;
}

export function setSecret(state: RoomState, playerId: string, secret: unknown, now: number): void {
  const seat = seatOf(state, playerId);
  if (state.phase !== 'setting') throw new RoomError('지금은 숫자를 정할 수 없어요');
  const error = validateGuess(secret);
  if (error) throw new RoomError(error);
  const player = state.players[seat];
  if (player.secret !== null) throw new RoomError('이미 숫자를 정했어요');
  player.secret = secret as string;
  state.updatedAt = now;

  if (state.players.every((p) => p.secret !== null)) {
    state.phase = 'playing';
    state.turn = state.firstSeat;
    state.turnDeadline = now + TURN_MS;
    state.lastEvent = null;
  }
}

export function guess(state: RoomState, playerId: string, value: unknown, now: number): GuessEntry {
  const seat = seatOf(state, playerId);
  if (state.phase !== 'playing') throw new RoomError('지금은 던질 수 없어요');
  if (state.turn !== seat) throw new RoomError('상대 차례예요');
  const error = validateGuess(value);
  if (error) throw new RoomError(error);
  const player = state.players[seat];
  if (player.guesses.length >= MAX_GUESSES_PER_PLAYER) throw new RoomError('더 이상 던질 수 없어요');

  const target = state.players[other(seat)].secret as string;
  const result = judge(target, value as string);
  const entry: GuessEntry = { guess: value as string, ...result };
  player.guesses.push(entry);
  state.updatedAt = now;
  state.lastEvent = null;

  if (result.strikes === DIGITS) {
    state.phase = 'finished';
    state.winner = seat;
    state.endReason = 'solved';
    state.turnDeadline = null;
  } else {
    state.turn = other(seat);
    state.turnDeadline = now + TURN_MS;
  }
  return entry;
}

/** 제한 시간이 지났으면 차례를 넘긴다. 넘겼으면 true. */
export function expireTurn(state: RoomState, now: number): boolean {
  if (state.phase !== 'playing' || state.turnDeadline === null || now < state.turnDeadline) {
    return false;
  }
  state.lastEvent = { type: 'timeout', seat: state.turn, at: now };
  state.turn = other(state.turn);
  state.turnDeadline = now + TURN_MS;
  return true;
}

/** 나가기. 대결 중(숫자 정하기 포함)에 나가면 기권패. */
export function leave(state: RoomState, playerId: string, now: number): void {
  const seat = seatOf(state, playerId);
  const player = state.players[seat];
  state.updatedAt = now;

  if (state.phase === 'waiting') {
    state.players.splice(seat, 1);
    return;
  }
  player.left = true;
  player.connected = false;
  player.rematch = false;
  if (state.phase === 'setting' || state.phase === 'playing') {
    state.phase = 'finished';
    state.winner = other(seat);
    state.endReason = 'forfeit';
    state.turnDeadline = null;
  }
}

export function disconnect(state: RoomState, playerId: string): void {
  const player = state.players.find((p) => p.id === playerId);
  if (player) player.connected = false;
}

/** 한 판 더. 둘 다 누르면 새 판을 시작하고 선공을 바꾼다. */
export function requestRematch(state: RoomState, playerId: string, now: number): void {
  const seat = seatOf(state, playerId);
  if (state.phase !== 'finished') throw new RoomError('대결이 끝난 뒤에 할 수 있어요');
  if (state.players.length < 2 || state.players.some((p) => p.left)) {
    throw new RoomError('상대가 방을 나갔어요');
  }
  state.players[seat].rematch = true;
  state.updatedAt = now;

  if (state.players.every((p) => p.rematch)) {
    for (const p of state.players) {
      p.secret = null;
      p.guesses = [];
      p.rematch = false;
    }
    state.round += 1;
    state.firstSeat = other(state.firstSeat);
    state.phase = 'setting';
    state.winner = null;
    state.endReason = null;
    state.turnDeadline = null;
    state.lastEvent = null;
  }
}

/** 한 참가자에게 보낼 화면 상태. 상대 비밀 숫자는 끝났을 때만 보여준다. */
export function viewFor(state: RoomState, playerId: string, now: number) {
  const seat = state.players.findIndex((p) => p.id === playerId);
  const me = state.players[seat];
  const opp = seat >= 0 ? state.players[other(seat)] : undefined;
  return {
    type: 'state' as const,
    code: state.code,
    phase: state.phase,
    round: state.round,
    serverNow: now,
    you: seat,
    turn: state.phase === 'playing' ? state.turn : null,
    turnDeadline: state.turnDeadline,
    firstSeat: state.firstSeat,
    winner: state.winner,
    endReason: state.endReason,
    lastEvent: state.lastEvent,
    me: me
      ? {
          name: me.name,
          secret: me.secret,
          guesses: me.guesses,
          rematch: me.rematch,
        }
      : null,
    opponent: opp
      ? {
          name: opp.name,
          connected: opp.connected,
          left: opp.left,
          ready: opp.secret !== null,
          rematch: opp.rematch,
          // 상대가 내 숫자를 맞히려고 던진 기록. 내 숫자이므로 보여줘도 된다.
          guesses: opp.guesses,
          secret: state.phase === 'finished' ? opp.secret : null,
        }
      : null,
  };
}

export type RoomView = ReturnType<typeof viewFor>;
