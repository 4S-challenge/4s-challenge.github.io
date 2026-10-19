# 4S 챌린지 - 숫자야구

숨겨진 네 자리 숫자를 추리하는 숫자야구 게임. Flutter 하나로 웹과 Android/iOS 앱을 함께 만듭니다.

- 웹: https://4s-challenge.github.io

## 규칙

- 비밀 숫자는 서로 다른 숫자 4개 (0으로 시작 가능)
- **S(스트라이크)**: 숫자와 자리가 모두 맞음 · **B(볼)**: 숫자는 있지만 자리가 다름 · **OUT**: 맞는 숫자 없음
- 4S면 정답. 혼자 하기는 10번 안에 맞혀야 함

## 현재 상태

| 기능 | 상태 |
| --- | --- |
| 혼자 하기 (컴퓨터 상대) | ✅ |
| 결과 화면 · 결과 복사 | ✅ |
| 웹 키보드 입력 (숫자, Backspace, Enter) | ✅ |
| 친구와 대결 (온라인 1:1) | 준비 중 — Cloudflare Workers + Durable Objects |
| 랭킹 | 준비 중 — Cloudflare D1 |

## 구조

```
lib/
  main.dart, app.dart
  game/
    game_logic.dart   # 판정·검증·비밀 숫자 생성 (순수 로직)
    solo_game.dart    # 혼자 하기 상태 (ChangeNotifier)
  screens/            # 홈, 혼자 하기, 결과
  theme/app_theme.dart
  widgets/common.dart # 전광판 숫자, S/B/OUT 배지, 버튼, 규칙 시트
test/                 # 로직·상태·위젯 테스트
web/                  # 웹 진입점
```

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
