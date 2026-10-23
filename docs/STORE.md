# 스토어 출시 준비

Google Play와 App Store에 "4S 챌린지 - 숫자야구"를 올리기 위한 체크리스트. 빌드 방법과 서명 키·딥링크 설정 자세한 내용은 [README](../README.md#앱-androidios)에 있습니다.

## 한눈에 보기

| 항목 | 값 |
| --- | --- |
| 앱 이름 | 4S 챌린지 - 숫자야구 (13자, Play·App Store 모두 30자 이내) |
| 홈 화면 이름 | 4S 챌린지 |
| 패키지 ID / 번들 ID | `com.ohsang.play.fourschallenge` (Android·iOS 공통, 출시 후 변경 불가) |
| 카테고리 | 게임 › 퍼즐 |
| 가격 | 무료, 인앱 결제 없음. **앱에 하단 배너 광고(AdMob)** 있음 (웹은 광고 없음) |
| 개인정보처리방침 | https://4s-challenge.github.io/privacy.html |
| 예상 등급 | 전체이용가 (IARC), App Store 4+ |
| 서버 | Cloudflare Worker `four-s-challenge-api` (빌드 때 `config/prod.json`으로 주소 주입) |

## 지켜야 할 것

- 이름·설명·스크린샷에 **"Mastermind"**(상표)를 쓰지 않는다. "숫자야구", "숫자 추리 게임"으로 설명한다.
- **KBO 구단명·로고·선수명**을 쓰지 않는다. 야구장 전광판 분위기만 쓴다.
- **현금·경품·상품권 등 보상**이 있는 기능(랭킹 상품 이벤트 포함)을 넣지 않는다. 넣으면 사행성 문제로 등급과 심사가 달라진다.
- 웹 버전(4s-challenge.github.io)을 국내에서 직접 서비스하는 것은 스토어 등급과 별개로 **게임물관리위원회 등급분류**가 필요할 수 있다. 스토어 앱은 각 스토어의 자체등급분류(IARC 등)로 처리된다.

## 1. 계정 준비

| | Google Play | App Store |
| --- | --- | --- |
| 계정 | [Play Console](https://play.google.com/console) 개발자 계정 (개인, 등록비 1회 25달러, 신분 확인) | [Apple Developer Program](https://developer.apple.com/programs/) (연 99달러) |
| 필요한 것 | 공개 연락처 이메일 (스토어에 표시됨) | Mac + Xcode (빌드·업로드), 공개 지원 URL |
| 주의 | **2023년 11월 이후 만든 개인 계정**은 프로덕션 출시 전에 **테스터 12명 이상이 14일 동안 비공개 테스트**를 해야 함 | 번들 ID 등록 때 **Associated Domains** 기능을 켜야 초대 링크가 앱으로 열림 |

공개 연락처 이메일·지원 URL은 계정 이메일 대신 프로젝트용 주소를 따로 만드는 것을 권장합니다. 지원 URL은 `https://github.com/4S-challenge/4s-challenge.github.io/issues`를 써도 됩니다.

## 2. 스토어 등록 정보 (초안)

**짧은 설명** (Play 80자 / App Store 부제 30자)

- Play: `숨겨진 네 자리 숫자를 추리하는 숫자야구. 혼자 랭킹 도전, 친구와 1:1 대결!`
- App Store 부제: `네 자리 숫자를 추리하는 숫자야구`

**자세한 설명**

```
숨겨진 네 자리 숫자, 몇 번 만에 맞힐 수 있을까요?

4S 챌린지는 서로 다른 숫자 4개로 된 비밀 숫자를 추리하는 숫자야구 게임입니다.
숫자 네 개를 던지면 결과가 야구장 전광판처럼 표시됩니다.

● S(스트라이크): 숫자와 자리가 모두 맞음
● B(볼): 숫자는 있지만 자리가 다름
● OUT: 맞는 숫자가 하나도 없음
4S가 나오면 정답!

[혼자 하기]
횟수 제한 없이 도전하고, 정답을 맞히면 이니셜 세 글자로 랭킹에 등록하세요.
적은 시도, 짧은 시간 순으로 순위가 매겨집니다.

[친구와 대결]
방을 만들고 방 코드나 초대 링크를 보내면 친구와 1:1로 겨룰 수 있어요.
각자 상대가 맞힐 비밀 숫자를 정하고, 번갈아 던져 먼저 4S를 만드는 사람이 승리!
차례마다 30초 제한이 있어요.

로그인 없이 바로 시작할 수 있고, 결제가 없습니다.
```

**키워드** (App Store, 100자, 쉼표로 구분): `숫자야구,숫자게임,추리,퍼즐,두뇌,브레인,야구,스트라이크,볼,대결,친구,랭킹`

## 3. 그래픽 자료

| 자료 | Google Play | App Store |
| --- | --- | --- |
| 앱 아이콘 | 512×512 PNG → [`store/icon-512.png`](../store/icon-512.png) | 빌드에 포함 (1024×1024, 자동) |
| 대표 이미지 | **1024×500 PNG/JPG 필수** → [`store/feature-graphic-1024x500.png`](../store/feature-graphic-1024x500.png) | 없음 |
| 휴대폰 스크린샷 | 2~8장, 9:16 권장 (예: 1080×1920) | 6.9인치 iPhone **1320×2868** (또는 1290×2796) 필수, 최대 10장 |
| 태블릿 스크린샷 | 선택 (안 올림) | 필요 없음 (iPhone 전용) |

`store/`의 두 이미지는 `python3 tools/make_store_graphics.py`로 다시 만들 수 있습니다(아이콘을 바꾼 뒤 실행). 대표 이미지는 Play에서 가장자리가 잘리거나 위에 재생 버튼이 얹힐 수 있어 중요한 글자를 가운데 쪽에 두었습니다.

iOS 앱은 **iPhone 전용**입니다(`TARGETED_DEVICE_FAMILY = 1`). iPad 스크린샷은 필요 없고, iPad에서는 iPhone 앱이 확대된 화면으로 실행됩니다.

**스크린샷** (6장, 만들어 둠)

| 순서 | 화면 | 문구 |
| --- | --- | --- |
| 1 | 홈 | 숨겨진 네 자리 숫자, 몇 번 만에 맞힐까? |
| 2 | 혼자 하기 진행 중 | S·B·OUT 힌트로 추리하는 숫자야구 |
| 3 | 친구와 대결 | 친구와 번갈아 던지는 1:1 실시간 대결 |
| 4 | 정답 화면 | 정답을 맞히면 이니셜로 랭킹 등록 |
| 5 | 랭킹 | 적은 시도, 빠른 시간으로 랭킹 1위에 도전 |
| 6 | 친구 초대(방 코드) | 방 코드 하나로 친구를 바로 초대 |

- Google Play: `store/screenshots/android/01~06.png` (1080×1920)
- App Store 6.9인치: `store/screenshots/iphone/01~06.png` (1320×2868)
- 문구 없는 화면만: 각 폴더의 `raw/`

화면 속 기록·랭킹·이니셜은 보여주기용 예시 데이터입니다.

**다시 만들기** (화면을 바꾼 뒤)

1. GitHub **Actions → Store screenshots → Run workflow**: 실제 앱 화면을 Android·iPhone 크기로 렌더링해 Artifacts(`store-screenshots`)에 올립니다. 장면은 `store_screenshots/store_screenshots_test.dart`에 있습니다. 로컬에서는 `bash tool/store_screenshots.sh` (Flutter 필요)
2. 받은 이미지를 `store_screenshots/out/`에 넣고 `python3 tools/make_store_screenshots.py`로 문구를 얹습니다. 문구는 스크립트의 `SHOTS`에서 바꿉니다.

## 3-1. 광고 (AdMob 하단 배너)

앱(Android/iOS)의 **홈, 결과, 랭킹, 대결 로비, 대결 대기·결과 화면 맨 아래**에 배너 광고(320×50)가 나옵니다. 숫자 키패드가 아래에 있는 게임 화면(혼자 하기, 숫자 정하기, 대결 중)에는 실수 클릭을 막기 위해 넣지 않았습니다(AdMob 정책). 웹에는 광고가 없습니다.

**Android는 실제 AdMob ID**가 들어가 있습니다. iOS는 아직 테스트 ID이고, iOS를 출시할 때 AdMob에 iOS 앱을 추가해 바꿉니다.

| 어디 | 값 | 지금 |
| --- | --- | --- |
| `config/prod.json` → `ADMOB_ANDROID_APP_ID` | Android 앱 ID (`~` 들어간 것) | `ca-app-pub-3934873497580609~7638623260` (실제) |
| `config/prod.json` → `ADMOB_ANDROID_BANNER_ID` | Android 배너 광고 단위 ID (`/` 들어간 것, 하단 배너) | `ca-app-pub-3934873497580609/3224735535` (실제) |
| `config/prod.json` → `ADMOB_IOS_BANNER_ID` | iOS 배너 광고 단위 ID | `ca-app-pub-3940256099942544/2934735716` (테스트) |
| `ios/Runner/Info.plist` → `GADApplicationIdentifier` | iOS 앱 ID | `ca-app-pub-3940256099942544~1458002511` (테스트) |

- 디버그 빌드(`flutter run`)는 설정과 상관없이 항상 테스트 광고를 씁니다(`lib/ads/banner_ad_mobile.dart`). 실제 광고는 릴리스 빌드(스토어용 AAB)에서만 나옵니다.
- `https://4s-challenge.github.io/app-ads.txt` (`web/app-ads.txt`)에 AdMob 게시자 ID 한 줄을 올려 두었습니다. Play 스토어 등록정보의 **웹사이트**를 `https://4s-challenge.github.io`로 넣어야 AdMob이 이 파일을 찾습니다.
- 스토어에 출시한 뒤 AdMob **앱 › 앱 설정 › 앱 스토어 연결**로 Play 스토어 앱을 연결하면 AdMob 앱 검토가 시작됩니다. 통과 전에는 광고가 적게 나오거나 안 나올 수 있습니다.
- Android 앱 ID는 빌드할 때 `config/prod.json`에서 `AndroidManifest.xml`로 들어갑니다(`android/app/build.gradle.kts`).
- **스토어에서 받은 앱(릴리스)에 나오는 내 광고를 직접 누르면 안 됩니다**(무효 클릭으로 계정이 제한될 수 있음). 내 기기에서 확인할 때는 AdMob **설정 › 테스트 기기**에 기기를 등록합니다.
- 유럽(EEA·영국) 이용자에게는 AdMob 동의 팝업(UMP)이 필요합니다. 처음에는 **한국(또는 유럽 제외 국가)에만 출시**하는 것을 권장합니다.

## 4. 등급 (IARC / App Store 연령 등급)

Play Console **정책 › 앱 콘텐츠 › 콘텐츠 등급**에서 IARC 설문을 작성합니다. 카테고리는 **게임**.

| 질문 | 답 | 이유 |
| --- | --- | --- |
| 폭력, 공포, 성적 콘텐츠, 비속어, 약물·알코올·담배 | 아니요 | 숫자와 S/B/OUT만 나옴 |
| 도박·모의 도박, 현금·경품 보상 | 아니요 | 보상 기능 없음 |
| 사용자 간 상호작용·콘텐츠 공유 | **예** | 친구와 대결(상대 이니셜·숫자 표시), 공개 랭킹(이니셜) |
| 사용자 간 채팅·메시지 | 아니요 | 자유 입력 없음. 이니셜은 영문 대문자 3글자만 |
| 위치 공유 | 아니요 | |
| 디지털 상품 구매 | 아니요 | |

예상 결과: 전체이용가(GRAC), PEGI 3, ESRB Everyone, 그리고 "사용자 상호작용" 표시가 붙을 수 있습니다.

이니셜 3글자로 욕설 약어를 만들 수 없도록 서버가 금지 목록으로 거릅니다(`worker/src/game.ts`의 `BLOCKED_INITIALS`, 랭킹 등록과 대결방 이름에 모두 적용). 새로 막을 이니셜이 생기면 목록에 추가하고, 이미 올라간 랭킹은 D1에서 따로 지웁니다. 랭킹 전체를 비우려면 GitHub **Actions → Clear rankings → Run workflow**에서 확인란에 `DELETE`를 입력해 실행합니다(지우기 전 기록은 Artifacts에 백업).

App Store Connect의 연령 등급 설문도 같은 기준으로 모두 "없음"으로 답합니다. 사용자 생성 콘텐츠 관련 질문에는 이니셜 표시를 기준으로 답합니다. 예상 결과: 4+.

**Play 타깃 연령층**(정책 › 앱 콘텐츠 › 타겟층 및 콘텐츠): 13세 미만을 포함하면 가족 정책 요건(광고·데이터 수집 제한 등)을 추가로 지켜야 합니다. 이 앱은 대부분 이미 충족하지만, 처음에는 **13세 이상**으로 선택하는 것이 심사가 간단합니다.

## 5. 개인정보 (데이터 보안 / 앱 개인정보 보호)

처리방침: https://4s-challenge.github.io/privacy.html (홈 화면 아래 링크에서도 열림)

**Google Play › 앱 콘텐츠 › 데이터 보안**

| 질문 | 답 |
| --- | --- |
| 필수 데이터 유형을 수집하거나 공유하나요? | 예 |
| 전송 중 암호화 | 예 (HTTPS/WSS) |
| 계정 만들기 | 계정 없음 (계정 삭제 URL 불필요) |
| 수집 데이터 | **앱 활동 › 기타 사용자 제작 콘텐츠**: 랭킹·대결 이니셜, 게임 기록 |
| └ 수집 / 공유 | 수집함, 제3자 공유 안 함 (Cloudflare는 서비스 제공자라 "공유"에 해당 안 됨) |
| └ 필수 여부 | 선택 (랭킹 등록·대결을 안 하면 수집 안 함) |
| └ 목적 | 앱 기능 |
| 수집 데이터 (광고) | **기기 또는 기타 ID**: 광고 ID — AdMob SDK가 수집 |
| └ 수집 / 공유 | 수집함, **공유함**(Google, 광고 목적) |
| └ 필수 여부 | 필수 (앱에 광고가 나오면 항상 처리됨) |
| └ 목적 | 광고 또는 마케팅, 분석, 사기 방지·보안 |
| 수집 데이터 (광고 SDK) | **앱 활동 › 앱 상호작용**(광고 노출·클릭), **앱 정보 및 성능 › 비정상 종료 로그·진단** — AdMob SDK 기준. 최신 항목은 [AdMob 데이터 공개 안내](https://developers.google.com/admob/android/privacy/play-data-disclosure)를 확인 |
| 데이터 삭제 요청 | 가능. 처리방침의 문의처(GitHub Issues) |
| 위치, 연락처 | 수집 안 함 |

**App Store Connect › 앱 개인정보 보호**

- 데이터 유형: **사용자 콘텐츠 › 기타 사용자 콘텐츠** (이니셜) — 사용자와 연결됨: 아니요 / 추적: 아니요 / 목적: 앱 기능
- 광고(AdMob): **식별자 › 기기 ID**, **사용 데이터 › 광고 데이터·제품 상호작용**, **진단** — 목적: 서드파티 광고, 분석. 맞춤형 광고를 쓰면 "추적: 예"와 앱의 추적 허용 요청(ATT) 팝업이 필요합니다. 지금 앱은 ATT 팝업 없이 동작하므로 iOS에서는 맞춤형이 아닌 광고가 나갑니다. [AdMob iOS 개인정보 안내](https://developers.google.com/admob/ios/privacy/data-disclosure)

**수출 규정(iOS)**: HTTPS만 쓰므로 `ios/Runner/Info.plist`에 `ITSAppUsesNonExemptEncryption = false`를 넣어 두었습니다. 업로드할 때마다 묻지 않습니다.

## 6. Android 출시 순서

1. **서명 키**: README의 "Android 서명 (업로드 키)"대로 업로드 키를 만들고 GitHub 시크릿 4개를 등록한다. 키스토어 파일과 비밀번호는 저장소 밖에 백업한다.
2. `main`에 머지 → Actions **Build Android app bundle** → Artifacts에서 `app-release-<번호>` 다운로드.
3. Play Console에서 앱 만들기 (이름, 기본 언어 한국어, 게임, 무료).
4. **Play 앱 서명** 사용 (기본값). 첫 AAB를 올리면 Google이 앱 서명 키를 관리한다.
5. **설정 › 앱 서명**에서 앱 서명 키 SHA-256과 업로드 키 SHA-256을 복사해, GitHub 저장소 변수 `ANDROID_CERT_SHA256`에 쉼표로 이어 넣는다 → main 배포 후 초대 링크가 앱으로 열림.
6. 앱 콘텐츠(처리방침, **광고: 예**, **광고 ID: 예(광고 목적)**, 등급, 타깃층, 데이터 보안, 정부 앱 아님 등)를 모두 작성한다.
7. **비공개 테스트** 트랙에 올리고 테스터 12명 이상이 14일 동안 참여 → 프로덕션 신청 (개인 계정 조건).
8. 프로덕션 출시.

## 7. iOS 출시 순서 (Mac 필요)

1. Apple Developer에서 App ID `com.ohsang.play.fourschallenge` 등록, **Associated Domains** 켜기.
2. Team ID를 GitHub 저장소 변수 `APPLE_TEAM_ID`에 넣는다 → main 배포 후 Universal Links 검증 파일이 올라감.
3. Mac에서 저장소를 받아 Xcode로 `ios/Runner.xcworkspace`를 열고 Signing & Capabilities에서 팀 선택 (자동 서명).
4. 빌드·업로드:
   ```bash
   flutter build ipa --dart-define-from-file=config/prod.json
   ```
   만들어진 `build/ios/ipa/*.ipa`를 Transporter 앱이나 Xcode Organizer로 업로드.
5. App Store Connect에서 앱 만들기 → TestFlight로 확인 → 등록 정보·스크린샷·개인정보·연령 등급 작성 → 심사 제출.

Mac이 없으면 GitHub Actions의 macOS 러너나 Codemagic 같은 CI로 빌드·업로드할 수 있습니다(인증서·프로비저닝 프로필을 시크릿으로 등록). 처음 한 번은 Mac에서 직접 해 보는 것을 권장합니다.

## 8. 출시 전 마지막 확인

- [ ] `pubspec.yaml`의 `version` 이름 (예: `1.0.0`). 버전 코드는 CI 실행 번호가 자동으로 씀
- [ ] 릴리스 빌드가 서버에 붙는지: 혼자 하기에서 "오프라인 모드" 표시가 **없어야** 함
- [ ] 랭킹 등록, 친구와 대결(두 기기), 초대 링크 열기
- [ ] 홈 화면 아래 개인정보처리방침 링크
- [ ] 아이콘·앱 이름(홈 화면 "4S 챌린지")
- [ ] 등록 정보·스크린샷에 Mastermind·KBO 표현이 없는지
