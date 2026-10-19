import 'dart:async';

import 'package:flutter/material.dart';

import 'api/four_s_api.dart';
import 'invite_link.dart';
import 'screens/home_screen.dart';
import 'screens/versus_lobby_screen.dart';
import 'theme/app_theme.dart';

class FourSApp extends StatefulWidget {
  const FourSApp({super.key, this.api, this.initialRoomCode, this.inviteLinks});

  /// 테스트에서 넘기는 서버 클라이언트. 없으면 빌드 설정(API_BASE_URL)을 따른다.
  final FourSApi? api;

  /// 초대 링크로 들어온 방 코드 (웹).
  final String? initialRoomCode;

  /// 앱으로 들어오는 초대 링크 (Android App Links / iOS Universal Links).
  final Stream<Uri>? inviteLinks;

  @override
  State<FourSApp> createState() => _FourSAppState();
}

class _FourSAppState extends State<FourSApp> {
  late final FourSApi? _api = widget.api ?? FourSApi.fromEnvironment();
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _links = widget.inviteLinks?.listen(_onInviteLink);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  void _onInviteLink(Uri uri) {
    final code = roomCodeFromUri(uri);
    if (code == null) return;
    // 앱을 막 켰을 때는 화면이 아직 없으니 첫 화면이 그려진 뒤에 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigator.currentState;
      if (navigator == null) return;
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => VersusLobbyScreen(initialCode: code)),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      api: _api,
      child: MaterialApp(
        navigatorKey: _navigator,
        title: '4S 챌린지 - 숫자야구',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeScreen(initialRoomCode: widget.initialRoomCode),
      ),
    );
  }
}
