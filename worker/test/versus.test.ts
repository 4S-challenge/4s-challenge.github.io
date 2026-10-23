import { describe, expect, it } from 'vitest';
import {
  RoomError,
  TURN_MS,
  createRoom,
  disconnect,
  expireTurn,
  guess,
  isRoomCode,
  join,
  leave,
  MAX_SPECTATORS,
  peek,
  randomRoomCode,
  requestRematch,
  setSecret,
  viewFor,
} from '../src/versus';

const T0 = 1_000_000;

function twoPlayers(firstSeat = 0) {
  const s = createRoom('K7Q2', T0);
  const a = join(s, { name: 'AAA', newId: 'a', firstSeat }, T0);
  const b = join(s, { name: 'BBB', newId: 'b', firstSeat }, T0);
  return { s, a, b };
}

function playing(firstSeat = 0) {
  const r = twoPlayers(firstSeat);
  setSecret(r.s, 'a', '1234', T0); // B가 맞혀야 하는 숫자
  setSecret(r.s, 'b', '5678', T0); // A가 맞혀야 하는 숫자
  return r;
}

describe('방 코드', () => {
  it('헷갈리는 글자 없이 4글자', () => {
    for (let i = 0; i < 200; i++) {
      const code = randomRoomCode();
      expect(isRoomCode(code)).toBe(true);
      expect(code).not.toMatch(/[01ILO]/);
    }
    expect(isRoomCode('ABC')).toBe(false);
    expect(isRoomCode('AB0D')).toBe(false);
  });
});

describe('입장', () => {
  it('두 명이 들어오면 숫자 정하기로 넘어간다', () => {
    const s = createRoom('K7Q2', T0);
    join(s, { name: 'AAA', newId: 'a', firstSeat: 1 }, T0);
    expect(s.phase).toBe('waiting');
    join(s, { name: 'BBB', newId: 'b', firstSeat: 1 }, T0);
    expect(s.phase).toBe('setting');
    expect(s.firstSeat).toBe(1);
  });

  it('세 번째 사람은 들어올 수 없다', () => {
    const { s } = twoPlayers();
    expect(() => join(s, { name: 'CCC', newId: 'c', firstSeat: 0 }, T0)).toThrow(RoomError);
  });

  it('이니셜이 올바르지 않으면 거부', () => {
    const s = createRoom('K7Q2', T0);
    expect(() => join(s, { name: 'ab', newId: 'a', firstSeat: 0 }, T0)).toThrow(RoomError);
  });

  it('같은 playerId로 다시 들어오면 재접속', () => {
    const { s } = twoPlayers();
    disconnect(s, 'a');
    expect(s.players[0].connected).toBe(false);
    const id = join(s, { playerId: 'a', name: '', newId: 'zzz', firstSeat: 0 }, T0);
    expect(id).toBe('a');
    expect(s.players[0].connected).toBe(true);
    expect(s.players).toHaveLength(2);
  });
});

describe('숫자 정하기', () => {
  it('둘 다 정하면 선공부터 시작', () => {
    const { s } = twoPlayers(1);
    setSecret(s, 'a', '1234', T0);
    expect(s.phase).toBe('setting');
    setSecret(s, 'b', '5678', T0 + 5);
    expect(s.phase).toBe('playing');
    expect(s.turn).toBe(1);
    expect(s.turnDeadline).toBe(T0 + 5 + TURN_MS);
  });

  it('규칙에 맞지 않는 숫자, 두 번 정하기는 거부', () => {
    const { s } = twoPlayers();
    expect(() => setSecret(s, 'a', '1123', T0)).toThrow(RoomError);
    setSecret(s, 'a', '1234', T0);
    expect(() => setSecret(s, 'a', '5678', T0)).toThrow(RoomError);
  });
});

describe('대결', () => {
  it('번갈아 던지고, 상대 숫자로 판정한다', () => {
    const { s } = playing(0);
    expect(guess(s, 'a', '5687', T0 + 1)).toEqual({ guess: '5687', strikes: 2, balls: 2 });
    expect(s.turn).toBe(1);
    expect(() => guess(s, 'a', '5678', T0 + 2)).toThrow('상대 차례예요');
    expect(guess(s, 'b', '1243', T0 + 3)).toEqual({ guess: '1243', strikes: 2, balls: 2 });
    expect(s.turn).toBe(0);
  });

  it('4S면 그 사람이 이긴다', () => {
    const { s } = playing(0);
    guess(s, 'a', '5678', T0 + 1);
    expect(s.phase).toBe('finished');
    expect(s.winner).toBe(0);
    expect(s.endReason).toBe('solved');
    expect(s.turnDeadline).toBeNull();
    expect(() => guess(s, 'b', '1234', T0 + 2)).toThrow(RoomError);
  });

  it('30초가 지나면 차례가 넘어간다', () => {
    const { s } = playing(0);
    expect(expireTurn(s, T0 + TURN_MS - 1)).toBe(false);
    expect(expireTurn(s, T0 + TURN_MS)).toBe(true);
    expect(s.turn).toBe(1);
    expect(s.lastEvent).toEqual({ type: 'timeout', seat: 0, at: T0 + TURN_MS });
    expect(s.turnDeadline).toBe(T0 + 2 * TURN_MS);
  });

  it('대결 중에 나가면 기권패', () => {
    const { s } = playing(0);
    leave(s, 'b', T0 + 1);
    expect(s.phase).toBe('finished');
    expect(s.winner).toBe(0);
    expect(s.endReason).toBe('forfeit');
  });

  it('숫자 정하는 중에 나가도 기권패', () => {
    const { s } = twoPlayers();
    leave(s, 'a', T0 + 1);
    expect(s.winner).toBe(1);
    expect(s.endReason).toBe('forfeit');
  });

  it('대기 중에 나가면 방에서 빠진다', () => {
    const s = createRoom('K7Q2', T0);
    join(s, { name: 'AAA', newId: 'a', firstSeat: 0 }, T0);
    leave(s, 'a', T0);
    expect(s.players).toHaveLength(0);
    expect(s.phase).toBe('waiting');
  });
});

describe('한 판 더', () => {
  it('둘 다 누르면 새 판, 선공이 바뀐다', () => {
    const { s } = playing(0);
    guess(s, 'a', '5678', T0 + 1);
    requestRematch(s, 'a', T0 + 2);
    expect(s.phase).toBe('finished');
    requestRematch(s, 'b', T0 + 3);
    expect(s.phase).toBe('setting');
    expect(s.round).toBe(2);
    expect(s.firstSeat).toBe(1);
    expect(s.players.every((p) => p.secret === null && p.guesses.length === 0)).toBe(true);
  });

  it('상대가 나갔으면 할 수 없다', () => {
    const { s } = playing(0);
    leave(s, 'b', T0 + 1);
    expect(() => requestRematch(s, 'a', T0 + 2)).toThrow('상대가 방을 나갔어요');
  });
});

describe('화면 상태', () => {
  it('상대 비밀 숫자는 끝나기 전엔 보이지 않는다', () => {
    const { s } = playing(0);
    guess(s, 'a', '5687', T0 + 1);
    const va = viewFor(s, 'a', T0 + 2);
    expect(va.you).toBe(0);
    expect(va.me?.secret).toBe('1234');
    expect(va.opponent?.secret).toBeNull();
    expect(va.me?.guesses).toHaveLength(1);
    const vb = viewFor(s, 'b', T0 + 2);
    expect(vb.opponent?.guesses).toHaveLength(1); // 상대(A)가 내 숫자에 던진 기록
    expect(JSON.stringify(vb)).not.toContain('1234');

    guess(s, 'b', '0912', T0 + 3);
    guess(s, 'a', '5678', T0 + 4);
    expect(viewFor(s, 'b', T0 + 5).opponent?.secret).toBe('1234');
  });
});

describe('관전', () => {
  it('꽉 찬 방은 관전으로 물어볼 수 있게 요약을 보여준다', () => {
    const s = createRoom('K7Q2', T0);
    join(s, { name: 'AAA', newId: 'a', firstSeat: 0 }, T0);
    expect(peek(s)).toMatchObject({ full: false, players: ['AAA'], spectators: 0 });
    join(s, { name: 'BBB', newId: 'b', firstSeat: 0 }, T0);
    expect(peek(s)).toMatchObject({ full: true, phase: 'setting', players: ['AAA', 'BBB'] });
  });

  it('watch로 들어오면 관전자가 되고, 없으면 거부', () => {
    const { s } = playing();
    expect(() => join(s, { name: 'CCC', newId: 'c', firstSeat: 0 }, T0)).toThrow('이미 대결이 시작된 방이에요');
    const id = join(s, { name: 'CCC', newId: 'c', firstSeat: 0, watch: true }, T0 + 5);
    expect(id).toBe('c');
    expect(s.players).toHaveLength(2);
    expect(peek(s).spectators).toBe(1);
  });

  it('관전자에게는 두 사람 기록이 보이고 비밀 숫자는 끝날 때까지 숨긴다', () => {
    const { s } = playing();
    join(s, { name: 'CCC', newId: 'c', firstSeat: 0, watch: true }, T0);
    guess(s, 'a', '5687', T0);
    guess(s, 'b', '1290', T0);
    const v = viewFor(s, 'c', T0);
    expect(v.role).toBe('spectator');
    expect(v.me?.name).toBe('AAA');
    expect(v.me?.secret).toBeNull();
    expect(v.opponent?.secret).toBeNull();
    expect(v.me?.guesses.map((g) => g.guess)).toEqual(['5687']);
    expect(v.opponent?.guesses.map((g) => g.guess)).toEqual(['1290']);
    expect(v.spectators).toEqual([{ name: 'CCC', since: T0, me: true }]);
    expect(viewFor(s, 'a', T0).spectators).toEqual([{ name: 'CCC', since: T0 }]);

    guess(s, 'a', '5678', T0);
    const done = viewFor(s, 'c', T0);
    expect(done.me?.secret).toBe('1234');
    expect(done.opponent?.secret).toBe('5678');
    expect(done.winner).toBe(0);
  });

  it('관전자는 던지거나 숫자를 정할 수 없다', () => {
    const { s } = twoPlayers();
    join(s, { name: 'CCC', newId: 'c', firstSeat: 0, watch: true }, T0);
    expect(() => setSecret(s, 'c', '1234', T0)).toThrow(RoomError);
    setSecret(s, 'a', '1234', T0);
    setSecret(s, 'b', '5678', T0);
    expect(() => guess(s, 'c', '5678', T0)).toThrow(RoomError);
    expect(() => requestRematch(s, 'c', T0)).toThrow(RoomError);
  });

  it('관전자가 나가도 대결은 그대로, 끊겼다 다시 들어오면 이어서 본다', () => {
    const { s } = playing();
    join(s, { name: 'CCC', newId: 'c', firstSeat: 0, watch: true }, T0);
    disconnect(s, 'c');
    expect(peek(s).spectators).toBe(0);
    expect(join(s, { playerId: 'c', name: 'CCC', newId: 'x', firstSeat: 0, watch: true }, T0)).toBe('c');
    expect(peek(s).spectators).toBe(1);
    leave(s, 'c', T0);
    expect(s.phase).toBe('playing');
    expect(peek(s).spectators).toBe(0);
  });

  it('관전 인원 제한', () => {
    const { s } = playing();
    for (let i = 0; i < MAX_SPECTATORS; i++) {
      join(s, { name: 'CCC', newId: `c${i}`, firstSeat: 0, watch: true }, T0);
    }
    expect(() => join(s, { name: 'DDD', newId: 'd', firstSeat: 0, watch: true }, T0)).toThrow('가득');
  });

  it('한 판 더 해도 관전자는 남는다', () => {
    const { s } = playing();
    join(s, { name: 'CCC', newId: 'c', firstSeat: 0, watch: true }, T0);
    guess(s, 'a', '5678', T0);
    requestRematch(s, 'a', T0);
    requestRematch(s, 'b', T0);
    expect(s.phase).toBe('setting');
    expect(viewFor(s, 'c', T0).spectators).toHaveLength(1);
  });
});
