# 4S 챌린지 - 숫자야구

숨겨진 네 자리 숫자를 추리하는 숫자야구 게임. Flutter 하나로 웹과 Android/iOS 앱을 함께 만듭니다.

- 웹: https://4s-challenge.github.io

## 규칙

- 비밀 숫자는 서로 다른 숫자 4개 (0으로 시작 가능)
- **S(스트라이크)**: 숫자와 자리가 모두 맞음 · **B(볼)**: 숫자는 있지만 자리가 다름 · **OUT**: 맞는 숫자 없음
- 4S면 정답. 횟수 제한 없이 몇 번 만에 맞혔는지 기록
- 정답을 맞히면 영문 대문자 3글자 이니셜로 랭킹 등록 (적은 시도 → 짧은 시간 순)

## 현재 상태

| 기능 | 상태 |
| --- | --- |
| 혼자 하기 (횟수 제한 없음, 서버 판정 / 오프라인 시 기기 판정) | ✅ |
| 결과 화면 · 결과 복사 | ✅ |
| 랭킹 등록 (이니셜 3글자) · 랭킹 보기 | ✅ — Cloudflare Workers + D1 (`worker/`) |
| 웹 키보드 입력 (숫자, Backspace, Enter) | ✅ |
| 친구와 대결 (온라인 1:1) | 준비 중 — Cloudflare Durable Objects |

## 구조

```
lib/
  main.dart, app.dart
  api/four_s_api.dart # 랭킹 서버 클라이언트
  game/
    game_logic.dart   # 판정·검증·비밀 숫자 생성 (순수 로직)
    solo_game.dart    # 혼자 하기 상태 (ChangeNotifier)
  screens/            # 홈, 혼자 하기, 결과, 랭킹
  theme/app_theme.dart
  widgets/common.dart # 전광판 숫자, S/B/OUT 배지, 버튼, 규칙 시트
test/                 # 로직·상태·위젯 테스트
web/                  # 웹 진입점
worker/               # Cloudflare Worker 랭킹 서버 (TypeScript + D1)
```

## 랭킹 서버 (Cloudflare)

혼자 하기의 비밀 숫자와 판정은 서버에서만 처리합니다. 그래서 기기에서 결과를 조작해 랭킹에 올릴 수 없습니다. 서버에 연결할 수 없으면 기기에서 판정하는 오프라인 모드로 진행하고, 이때는 랭킹에 등록할 수 없습니다.

| API | 설명 |
| --- | --- |
| `POST /api/solo/start` | 새 게임. 서버가 비밀 숫자를 만든다 |
| `POST /api/solo/guess` | `{gameId, guess}` 판정. 맞히면 걸린 시간 반환 |
| `POST /api/rankings` | `{gameId, initials}` 정답 맞힌 게임만, 한 번만, 24시간 안에 등록 |
| `GET /api/rankings?limit=50` | 랭킹 목록 |

### 처음 한 번 설정

1. Cloudflare 대시보드 → **Storage & Databases → D1** → 데이터베이스 생성 (이름 `four-s-challenge`) → Database ID 복사
2. Cloudflare **API 토큰** 생성: "Edit Cloudflare Workers" 템플릿 + 권한에 **D1 Edit** 추가
3. GitHub 저장소 **Settings → Secrets and variables → Actions**
   - Secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`
   - Variables: `D1_DATABASE_ID`
4. `main`에 머지(또는 Actions에서 다시 실행)하면 마이그레이션 → Worker 배포가 진행됩니다
5. 배포된 Worker 주소(예: `https://four-s-challenge-api.<계정>.workers.dev`)를 Variables의 `API_BASE_URL`에 넣고 다시 실행하면 웹이 랭킹 서버에 연결됩니다

설정이 없으면 Worker 배포는 건너뛰고 웹은 오프라인 모드로 배포됩니다.

## 로컬 실행

```bash
flutter pub get
flutter run -d chrome     # 웹
flutter test
```

Android/iOS 플랫폼 폴더는 아직 커밋되어 있지 않습니다. 앱으로 실행하려면 처음 한 번 아래 명령으로 생성하세요 (`lib/`는 그대로 유지됩니다).

```bash
flutter create --org io.github.fourschallenge --platforms=android,ios .
```

## 배포

`main`에 머지되면 GitHub Actions가 분석 → 테스트 → `flutter build web` → GitHub Pages 배포를 진행합니다. PR에서는 배포 없이 분석·테스트·빌드만 확인합니다.

처음 한 번은 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다.
