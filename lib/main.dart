import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ads/banner_ad.dart';
import 'app.dart';
import 'invite_link.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 광고 SDK는 기다리지 않고 뒤에서 준비한다 (앱에서만, 웹은 아무것도 안 함).
  initAds();
  runApp(FourSApp(
    // 웹: 페이지 주소의 ?room= 을 읽는다.
    initialRoomCode: kIsWeb ? roomCodeFromUri(Uri.base) : null,
    // 앱: 초대 링크로 앱을 켰을 때와, 켜져 있는 동안 링크를 열었을 때 모두 이 스트림으로 들어온다.
    inviteLinks: kIsWeb ? null : AppLinks().uriLinkStream,
  ));
}
