import 'package:flutter/material.dart';

import 'api/four_s_api.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class FourSApp extends StatefulWidget {
  const FourSApp({super.key, this.api, this.initialRoomCode});

  /// 테스트에서 넘기는 서버 클라이언트. 없으면 빌드 설정(API_BASE_URL)을 따른다.
  final FourSApi? api;

  /// 초대 링크로 들어온 방 코드.
  final String? initialRoomCode;

  @override
  State<FourSApp> createState() => _FourSAppState();
}

class _FourSAppState extends State<FourSApp> {
  late final FourSApi? _api = widget.api ?? FourSApi.fromEnvironment();

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      api: _api,
      child: MaterialApp(
        title: '4S 챌린지 - 숫자야구',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeScreen(initialRoomCode: widget.initialRoomCode),
      ),
    );
  }
}
