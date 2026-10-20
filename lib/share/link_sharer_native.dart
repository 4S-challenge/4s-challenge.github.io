import 'package:share_plus/share_plus.dart';

import 'link_sharer.dart';

LinkSharer createLinkSharer() => _NativeLinkSharer();

/// Android/iOS 앱: 기기 기본 공유 창(share_plus).
class _NativeLinkSharer implements LinkSharer {
  @override
  bool get canShare => true;

  @override
  Future<ShareOutcome> share({required String text, String? url, String? title}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: shareCopyText(text, url), subject: title, title: title),
      );
      return result.status == ShareResultStatus.dismissed
          ? ShareOutcome.cancelled
          : ShareOutcome.shared;
    } catch (_) {
      // 공유 창을 열 수 없는 기기(데스크톱 등)에서는 복사로 대신한다.
      return copyForShare(text, url);
    }
  }
}
