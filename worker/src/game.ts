export const DIGITS = 4;

export interface GuessResult {
  strikes: number;
  balls: number;
}

/** 서로 다른 숫자 4개인지 검사. 맞으면 null, 아니면 오류 메시지. */
export function validateGuess(value: unknown): string | null {
  if (typeof value !== 'string' || !/^[0-9]{4}$/.test(value)) {
    return '숫자 4개를 입력해 주세요';
  }
  if (new Set(value).size !== value.length) {
    return '같은 숫자는 한 번만 쓸 수 있어요';
  }
  return null;
}

export function judge(secret: string, guess: string): GuessResult {
  let strikes = 0;
  let balls = 0;
  for (let i = 0; i < guess.length; i++) {
    if (guess[i] === secret[i]) strikes++;
    else if (secret.includes(guess[i])) balls++;
  }
  return { strikes, balls };
}

/** 암호학적 난수로 비밀 숫자를 만든다. 0으로 시작할 수 있다. */
export function generateSecret(): string {
  const pool = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const out: string[] = [];
  const buf = new Uint32Array(1);
  while (out.length < DIGITS) {
    crypto.getRandomValues(buf);
    out.push(pool.splice(buf[0] % pool.length, 1)[0]);
  }
  return out.join('');
}

/** 랭킹에 쓸 수 없는 이니셜. */
const BLOCKED_INITIALS = new Set([
  'ASS', 'CUM', 'DIK', 'FAG', 'FUC', 'FUK', 'FUQ', 'KKK', 'NIG',
  'NGR', 'SEX', 'SHT', 'TIT', 'VAG', 'XXX', 'JOT', 'SSI', 'SIB', 'BYC',
]);

/** 영문 대문자 3글자인지 검사. 맞으면 null, 아니면 오류 메시지. */
export function validateInitials(value: unknown): string | null {
  if (typeof value !== 'string' || !/^[A-Z]{3}$/.test(value)) {
    return '영문 대문자 3글자를 입력해 주세요';
  }
  if (BLOCKED_INITIALS.has(value)) {
    return '쓸 수 없는 이니셜이에요';
  }
  return null;
}
