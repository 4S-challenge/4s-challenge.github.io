/**
 * 오상플레이 공용 서버 주소(api.ohsangplay.com)에서는 앱마다 경로 앞부분으로 나눈다.
 * 이 앱은 /4s 아래를 받는다: https://api.ohsangplay.com/4s/api/health → /api/health
 * workers.dev 주소(이미 출시된 앱이 씀)는 앞부분 없이 그대로 들어온다.
 */
export const PATH_PREFIX = '/4s';

export function stripPathPrefix(pathname: string): string {
  if (pathname === PATH_PREFIX) return '/';
  if (pathname.startsWith(`${PATH_PREFIX}/`)) return pathname.slice(PATH_PREFIX.length);
  return pathname;
}
