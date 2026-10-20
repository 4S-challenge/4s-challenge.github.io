import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'link_sharer.dart';

LinkSharer createLinkSharer() => _WebLinkSharer();

/// 웹: Web Share API(navigator.share)가 있으면 기기 공유 창, 없으면 복사.
/// 휴대폰 크롬·사파리·삼성 인터넷은 공유 창이 열린다.
class _WebLinkSharer implements LinkSharer {
  @override
  bool get canShare {
    final navigator = web.window.navigator;
    if (!(navigator as JSObject).has('share')) return false;
    return !isInAppBrowser(navigator.userAgent);
  }

  @override
  Future<ShareOutcome> share({required String text, String? url, String? title}) async {
    if (!canShare) return copyForShare(text, url);
    final data = web.ShareData(text: text);
    if (url != null && !text.contains(url)) data.url = url;
    if (title != null) data.title = title;
    try {
      // 공유 창은 버튼을 누른 그 순간에만 열 수 있어서, 이 앞에 await를 두지 않는다.
      await web.window.navigator.share(data).toDart;
      return ShareOutcome.shared;
    } catch (error) {
      // 사용자가 공유 창을 닫은 경우.
      if (_errorName(error) == 'AbortError' || '$error'.contains('AbortError')) {
        return ShareOutcome.cancelled;
      }
      // 그 밖의 실패(권한 거부, 지원하지 않는 내용 등)는 복사로 대신한다.
      return copyForShare(text, url);
    }
  }

  static String? _errorName(Object error) {
    try {
      final name = (error as JSObject)['name'];
      return name.isA<JSString>() ? (name as JSString).toDart : null;
    } catch (_) {
      return null;
    }
  }
}
