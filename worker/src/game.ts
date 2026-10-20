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

/**
 * 랭킹·대결방에 쓸 수 없는 이니셜 (영문 대문자 3글자).
 * 공개 랭킹에 그대로 보이므로 욕설·성적 표현·혐오 표현의 약어를 막는다.
 * 새로 막을 이니셜이 생기면 여기에 넣는다. 이미 등록된 랭킹은 따로 지워야 한다.
 */
export const BLOCKED_INITIALS: ReadonlySet<string> = new Set([
  // 영어 욕설·성적 표현
  'ASS', 'ANL', 'BCH', 'CNT', 'COK', 'CUM', 'DCK', 'DIC', 'DIK', 'FCK',
  'FKU', 'FUC', 'FUK', 'FUQ', 'HOE', 'JIZ', 'PIS', 'PNS', 'RPE', 'SEX',
  'SHT', 'SLT', 'SOB', 'TIT', 'TWT', 'VAG', 'WHR', 'WTF', 'XXX',
  // 자해 조장 ("kill yourself")
  'KYS',
  // 인종·성소수자 혐오, 혐오 단체
  'FAG', 'FGT', 'JAP', 'KKK', 'NGA', 'NGR', 'NIG',
  // 한국어 욕설의 로마자·초성·자판 약어
  'BYC', // 병신
  'GSK', // 개새끼
  'JNA', // 존나
  'JOT', // 좆
  'NGM', // 느금마
  'SIB', // 씨발
  'SSB', // ㅆㅂ
  'SSI', // 씨
  'TLQ', // 씨발 (한글 자판 tlqkf)
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
