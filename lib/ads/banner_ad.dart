/// 하단 배너 광고 (AdMob). 앱(Android/iOS)에서만 나오고, 웹·테스트에서는 아무것도 그리지 않는다.
///
/// 광고 단위 ID는 config/prod.json의 ADMOB_ANDROID_BANNER_ID / ADMOB_IOS_BANNER_ID.
/// 값이 없으면 Google 테스트 광고 ID를 쓴다.
library;

export 'banner_ad_stub.dart' if (dart.library.io) 'banner_ad_mobile.dart';
