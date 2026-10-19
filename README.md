# 4S 챌린지 - 숫자야구

숨겨진 네 자리 숫자를 추리하는 숫자야구 게임. Flutter 하나로 웹과 Android/iOS 앱을 함께 만듭니다.

- 웹: https://4s-challenge.github.io
- 개인정보처리방침: https://4s-challenge.github.io/privacy.html (`web/privacy.html`, 스토어 등록에 이 주소를 씀)

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
| 친구와 대결 (온라인 1:1, 방 코드·초대 링크) | ✅ — Cloudflare Durable Objects + WebSocket |

## 구조

```
lib/
  main.dart, app.dart
  invite_link.dart    # 초대 링크(?room=CODE)에서 방 코드 꺼내기 (웹 주소·앱 링크 공통)
  api/four_s_api.dart # 랭킹·대결 서버 클라이언트
  versus/             # 친구와 대결: 서버 상태 모델, WebSocket 연결·재접속
  game/
    game_logic.dart   # 판정·검증·비밀 숫자 생성 (순수 로직)
    solo_game.dart    # 혼자 하기 상태 (ChangeNotifier)
  screens/            # 홈, 혼자 하기, 결과, 랭킹, 대결 로비·대결방
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

## 친구와 대결

- 번갈아 한 번씩 던지고, 상대 숫자를 먼저 4S로 맞히면 승리. 차례당 30초, 넘기면 차례가 넘어감
- 각자 상대가 맞힐 비밀 숫자를 직접 정함 (서버만 알고, 끝난 뒤 공개)
- 방 만들기 → 4글자 방 코드 또는 초대 링크(`https://4s-challenge.github.io/?room=CODE`)로 입장
- 대결 중 나가면 기권패. 연결이 끊기면 자동으로 다시 연결하고 게임을 이어감
- 끝난 뒤 둘 다 '한 판 더'를 누르면 선공을 바꿔 새 판

| API | 설명 |
| --- | --- |
| `POST /api/versus/rooms` | 방 만들기 → `{code}` |
| `GET /api/versus/rooms/{code}/ws?name=AAA[&playerId=…]` | 방 WebSocket. 서버 → `welcome`, `state`, `error` / 앱 → `setSecret`, `guess`, `rematch`, `leave` |

방 하나가 Durable Object 하나이고, 방 규칙은 `worker/src/versus.ts`(순수 로직, 단위 테스트), 연결·저장·타이머는 `worker/src/room.ts`에 있습니다.

### 처음 한 번 설정

GitHub에 Cloudflare 시크릿 두 개만 넣으면 됩니다. 나머지(D1 데이터베이스 생성, 마이그레이션, Worker 배포, 웹에 서버 주소 연결)는 `main`에 배포될 때 GitHub Actions가 자동으로 합니다.

1. Cloudflare 대시보드 → 오른쪽 위 프로필 → **My Profile → API Tokens → Create Token**
   - **Edit Cloudflare Workers** 템플릿 선택 → 권한에 **Account · D1 · Edit** 추가
   - Account Resources: 사용할 계정, Zone Resources: All zones (도메인을 안 쓰면 그대로)
2. Cloudflare 대시보드 **Workers & Pages** 화면 오른쪽의 **Account ID** 복사
3. GitHub 저장소 **Settings → Secrets and variables → Actions → New repository secret**
   - `CLOUDFLARE_API_TOKEN`: 1번 토큰
   - `CLOUDFLARE_ACCOUNT_ID`: 2번 ID
4. **Actions → CI & Deploy → Run workflow**(main) 실행 또는 `main`에 머지

같은 Cloudflare 계정을 다른 프로젝트와 함께 써도 됩니다. Worker(`four-s-challenge-api`)와 D1(`four-s-challenge`)은 이름으로 분리되고, 토큰은 프로젝트별로 따로 만드는 것을 권장합니다.

서버 주소를 직접 정하고 싶으면(예: 커스텀 도메인) 저장소 변수 `API_BASE_URL`을 넣으면 그 값을 우선 사용합니다. 시크릿이 없으면 Worker 배포는 건너뛰고 웹은 오프라인 모드로 배포됩니다.

## 로컬 실행

```bash
flutter pub get
flutter run -d chrome     # 웹
flutter test
```

## 앱 (Android/iOS)

- 패키지 ID: `com.ohsang.fourschallenge` (Android·iOS 공통, 스토어에 올린 뒤에는 바꿀 수 없음)
- 홈 화면 이름: `4S 챌린지`

앱에는 서버 주소가 빌드할 때 들어갑니다. 주소는 `config/prod.json`에 있고, 앱을 빌드·실행할 때는 항상 이 파일을 넘깁니다.

```bash
flutter run --dart-define-from-file=config/prod.json
flutter build appbundle --dart-define-from-file=config/prod.json   # Android (Play 스토어)
flutter build ipa --dart-define-from-file=config/prod.json         # iOS (macOS에서)
```

Android 릴리스 빌드는 `API_BASE_URL`이 없으면 실패하도록 막아 두었습니다(`android/app/build.gradle.kts`). 실수로 오프라인 앱을 스토어에 올리지 않기 위해서입니다. 디버그 빌드는 주소 없이도 됩니다(오프라인 모드).

### 초대 링크로 앱 열기 (App Links / Universal Links)

초대 링크 `https://4s-challenge.github.io/?room=CODE`를 누르면, 앱이 설치된 기기에서는 앱의 대결 화면이 방 코드가 채워진 채로 열립니다. 앱이 없거나 아래 설정 전이면 지금처럼 웹이 열립니다. 링크 처리는 `lib/invite_link.dart`, `lib/app.dart`(`app_links` 패키지)에 있습니다.

Android·iOS가 "이 도메인은 이 앱 것"이라고 확인하려면 웹에 검증 파일이 있어야 합니다. 두 파일은 `main` 배포 때 CI가 저장소 변수로 만듭니다(**Settings → Secrets and variables → Actions → Variables**).

| 변수 | 값 | 만들어지는 파일 |
| --- | --- | --- |
| `ANDROID_CERT_SHA256` | Play Console → 앱 → **테스트 및 출시 → 설정 → 앱 서명**의 SHA-256 인증서 지문. 업로드 키 지문도 쉼표로 이어 붙이면 직접 설치한 빌드에서도 동작 | `/.well-known/assetlinks.json` |
| `APPLE_TEAM_ID` | Apple Developer → **Membership details**의 Team ID (10글자) | `/.well-known/apple-app-site-association` |

변수를 넣은 뒤 `main`에 배포하고 확인합니다.

- Android: `https://4s-challenge.github.io/.well-known/assetlinks.json` 이 열리는지, 기기에서 `adb shell pm get-app-links com.ohsang.fourschallenge` 결과가 `verified`인지
- iOS: `https://app-site-association.cdn-apple.com/a/v1/4s-challenge.github.io` 에서 Apple이 파일을 가져갔는지 (반영까지 최대 하루)

Android는 경로 `/`만 앱으로 받으므로 `/privacy.html` 같은 다른 페이지는 브라우저로 열립니다. iOS는 `?room=`이 붙은 링크만 앱으로 엽니다.

## 배포

`main`에 머지되면 GitHub Actions가 분석 → 테스트 → `flutter build web` → GitHub Pages 배포를 진행합니다. PR에서는 배포 없이 분석·테스트·빌드만 확인합니다.

처음 한 번은 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다.
