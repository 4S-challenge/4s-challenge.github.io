import 'package:four_s_challenge/share/link_sharer.dart';

/// 테스트용 공유 도구. [canShare]가 false면 실제처럼 클립보드 복사로 처리한다.
class FakeLinkSharer implements LinkSharer {
  FakeLinkSharer({this.canShare = true, this.outcome = ShareOutcome.shared});

  @override
  final bool canShare;

  /// 공유 창이 있을 때 돌려줄 결과.
  final ShareOutcome outcome;

  final List<({String text, String? url, String? title})> calls = [];

  @override
  Future<ShareOutcome> share({required String text, String? url, String? title}) async {
    calls.add((text: text, url: url, title: title));
    if (!canShare) return copyForShare(text, url);
    return outcome;
  }
}
