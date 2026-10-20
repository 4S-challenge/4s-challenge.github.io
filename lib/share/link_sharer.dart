import 'package:flutter/services.dart';

import 'link_sharer_native.dart'
    if (dart.library.js_interop) 'link_sharer_web.dart' as platform;

/// 공유 결과.
enum ShareOutcome {
  /// 기기 공유 창으로 보냈다.
  shared,

  /// 공유 창을 열었다가 닫았다.
  cancelled,

  /// 공유 창을 쓸 수 없어 클립보드에 복사했다.
  copied,
}

/// 공유 창 열기. 앱(Android/iOS)과 휴대폰 브라우저는 기기 기본 공유 창을,
/// 공유 창이 없는 곳(일부 PC 브라우저, 카카오톡 등 앱 안 브라우저)은 링크 복사를 쓴다.
abstract class LinkSharer {
  /// 기기 공유 창을 쓸 수 있는지. false면 [share]가 복사로 처리한다.
  /// 버튼 이름을 "공유"/"복사" 중 무엇으로 보여줄지 정할 때 쓴다.
  bool get canShare;

  /// [text]와 [url]을 공유한다. 공유 창을 못 쓰면 둘을 합쳐 복사한다.
  Future<ShareOutcome> share({required String text, String? url, String? title});
}

/// 앱 전체에서 쓰는 공유 도구. 테스트에서는 가짜로 바꿔 끼운다.
LinkSharer linkSharer = platform.createLinkSharer();

/// 공유 창 대신 쓰는 복사 문구: 본문 다음 줄에 링크.
String shareCopyText(String text, String? url) =>
    url == null || text.contains(url) ? text : '$text\n$url';

Future<ShareOutcome> copyForShare(String text, String? url) async {
  await Clipboard.setData(ClipboardData(text: shareCopyText(text, url)));
  return ShareOutcome.copied;
}

/// 앱 안 브라우저(인앱 브라우저)인지. 이런 곳은 공유 창이 없거나 있어도 제대로 동작하지 않아 복사를 쓴다.
/// 카카오톡, 네이버, 다음, 라인, 인스타그램, 페이스북, 에브리타임, 밴드, 안드로이드 WebView 등.
bool isInAppBrowser(String userAgent) => _inAppBrowser.hasMatch(userAgent);

final _inAppBrowser = RegExp(
  r'KAKAOTALK|NAVER\(inapp|DaumApps|Line/|Instagram|FBAN|FBAV|FB_IAB|everytimeApp|BAND/|; wv\)',
  caseSensitive: false,
);
