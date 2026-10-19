import { describe, expect, it } from 'vitest';
import { generateSecret, judge, validateGuess, validateInitials } from '../src/game';

describe('judge', () => {
  it('S/B/OUT을 판정한다', () => {
    expect(judge('4725', '1368')).toEqual({ strikes: 0, balls: 0 });
    expect(judge('4725', '1234')).toEqual({ strikes: 0, balls: 2 });
    expect(judge('4725', '4729')).toEqual({ strikes: 3, balls: 0 });
    expect(judge('4725', '4257')).toEqual({ strikes: 1, balls: 3 });
    expect(judge('4725', '4725')).toEqual({ strikes: 4, balls: 0 });
  });
});

describe('validateGuess', () => {
  it('서로 다른 숫자 4개만 허용한다', () => {
    expect(validateGuess('0123')).toBeNull();
    expect(validateGuess('123')).not.toBeNull();
    expect(validateGuess('1123')).not.toBeNull();
    expect(validateGuess('12a4')).not.toBeNull();
    expect(validateGuess(1234)).not.toBeNull();
  });
});

describe('generateSecret', () => {
  it('항상 규칙에 맞는 숫자를 만든다', () => {
    for (let i = 0; i < 500; i++) {
      expect(validateGuess(generateSecret())).toBeNull();
    }
  });
});

describe('validateInitials', () => {
  it('영문 대문자 3글자만 허용한다', () => {
    expect(validateInitials('ABC')).toBeNull();
    expect(validateInitials('abc')).not.toBeNull();
    expect(validateInitials('AB')).not.toBeNull();
    expect(validateInitials('ABCD')).not.toBeNull();
    expect(validateInitials('A1C')).not.toBeNull();
    expect(validateInitials('가나다')).not.toBeNull();
  });

  it('부적절한 이니셜은 막는다', () => {
    expect(validateInitials('ASS')).not.toBeNull();
  });
});
