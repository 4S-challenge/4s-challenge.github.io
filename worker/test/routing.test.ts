import { describe, expect, it } from 'vitest';
import { stripPathPrefix } from '../src/index';

describe('경로 앞부분(/4s)', () => {
  it('공용 API 도메인의 /4s 아래 경로를 원래 경로로 바꾼다', () => {
    expect(stripPathPrefix('/4s/api/health')).toBe('/api/health');
    expect(stripPathPrefix('/4s/api/versus/rooms/K7Q2/ws')).toBe('/api/versus/rooms/K7Q2/ws');
    expect(stripPathPrefix('/4s')).toBe('/');
  });

  it('workers.dev 주소처럼 앞부분이 없으면 그대로 둔다', () => {
    expect(stripPathPrefix('/api/rankings')).toBe('/api/rankings');
    expect(stripPathPrefix('/4sx/api')).toBe('/4sx/api');
  });
});
