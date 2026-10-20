// 스토어 스크린샷을 실제 앱 화면으로 만든다.
//
//   bash tool/store_screenshots.sh      (글꼴을 받고 아래 명령을 실행)
//   flutter test store_screenshots
//
// 결과: store_screenshots/out/<기기>/<번호>-<이름>.png (실제 픽셀 크기)
// 글꼴 파일은 store_screenshots/fonts/에 있어야 한다 (스크립트가 받아 둠, 커밋하지 않음).
// 화면 속 기록·랭킹은 보여주기용 예시 데이터다.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/game/game_logic.dart';
import 'package:four_s_challenge/game/solo_game.dart';
import 'package:four_s_challenge/screens/ranking_screen.dart';
import 'package:four_s_challenge/screens/result_screen.dart';
import 'package:four_s_challenge/screens/solo_play_screen.dart';
import 'package:four_s_challenge/screens/versus_room_screen.dart';
import 'package:four_s_challenge/share/link_sharer.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

import '../test/support/fake_server.dart';
import '../test/support/fake_sharer.dart';

/// 찍을 기기 크기 (논리 크기 × 배율 = 이미지 크기).
const devices = {
  // Google Play 휴대폰 1080×1920 (9:16)
  'android': (size: Size(360, 640), ratio: 3.0),
  // App Store 6.9인치 iPhone 1320×2868
  'iphone': (size: Size(440, 956), ratio: 3.0),
};

const _shotKey = ValueKey('store-shot');

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('store_screenshots/fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  const body = [
    'IBMPlexSansKR-Regular.ttf',
    'IBMPlexSansKR-Medium.ttf',
    'IBMPlexSansKR-Bold.ttf',
  ];
  await _loadFont('IBMPlexSansKR', body);
  // 글꼴을 따로 정하지 않은 글자(버튼 등)는 테스트 기본 글꼴로 그려져 한글이 네모가 된다.
  // 실제 기기에서는 시스템 글꼴이 쓰이므로, 여기서는 기본 글꼴 이름에 본문 글꼴을 넣는다.
  for (final family in ['FlutterTest', 'Roboto', '.SF UI Text', '.SF Pro Text']) {
    await _loadFont(family, body);
  }
  await _loadFont('BlackHanSans', ['BlackHanSans-Regular.ttf']);
  await _loadFont('SpaceMono', ['SpaceMono-Bold.ttf']);

  // 아이콘 글꼴은 Flutter SDK에 들어 있다.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
      await loader.load();
    }
  }

  AppFonts.useGoogleFonts = false;
  AppFonts.localBodyFamily = 'IBMPlexSansKR';
  AppFonts.localDisplayFamily = 'BlackHanSans';
  AppFonts.localMonoFamily = 'SpaceMono';
}

Map<String, Object> _rank(int id, String initials, int tries, int seconds) => {
      'id': id,
      'initials': initials,
      'tries': tries,
      'durationMs': seconds * 1000,
      'createdAt': 1792400000000 + id,
    };

void main() {
  setUpAll(_loadFonts);
  setUp(() => linkSharer = FakeLinkSharer());

  for (final entry in devices.entries) {
    final device = entry.key;
    final spec = entry.value;

    void useDevice(WidgetTester tester) {
      tester.view.physicalSize = spec.size * spec.ratio;
      tester.view.devicePixelRatio = spec.ratio;
      addTearDown(tester.view.reset);
    }

    Widget host(Widget home, {FourSApi? api}) => RepaintBoundary(
          key: _shotKey,
          child: ApiScope(
            api: api,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: home,
            ),
          ),
        );

    Future<void> shot(WidgetTester tester, String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: spec.ratio);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('store_screenshots/out/$device/$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    group(device, () {
      testWidgets('1 홈', (tester) async {
        useDevice(tester);
        await tester.pumpWidget(RepaintBoundary(
          key: _shotKey,
          child: FourSApp(api: FakeServer().api),
        ));
        await settle(tester);
        await shot(tester, '1-home');
      });

      testWidgets('2 혼자 하기', (tester) async {
        useDevice(tester);
        // 서버에 연결된 게임 (오프라인 표시 없이)
        final game = SoloGame(api: FakeServer(secret: '4725').api);
        await game.start();
        for (final guess in ['1234', '9031', '4790', '4752']) {
          for (final d in guess.split('')) {
            game.press(d);
          }
          await game.submit();
        }
        game
          ..press('4')
          ..press('7');
        await tester.pumpWidget(host(SoloPlayScreen(game: game)));
        await settle(tester);
        await shot(tester, '2-solo');
      });

      testWidgets('3 친구와 대결', (tester) async {
        useDevice(tester);
        final server = FakeServer();
        await tester.pumpWidget(host(
          const VersusRoomScreen(code: 'K7Q2', name: 'KIM'),
          api: server.api,
        ));
        await settle(tester);
        final socket = server.sockets.last;
        final now = DateTime.now().millisecondsSinceEpoch;
        socket
          ..serverSend({'type': 'welcome', 'playerId': 'p1'})
          ..serverSend(versusState(
            phase: 'playing',
            turn: 0,
            serverNow: now,
            turnDeadline: now + 21500,
            myName: 'KIM',
            mySecret: '5209',
            myGuesses: [g('1234', 0, 2), g('5670', 0, 1), g('3189', 1, 2)],
            opponent: versusOpponent(
              name: 'LEE',
              ready: true,
              guesses: [g('0123', 0, 2), g('4567', 0, 1), g('2890', 0, 3)],
            ),
          ));
        await settle(tester);
        for (final d in ['3', '8']) {
          await tester.tap(find.byKey(Key('vkey-$d')));
          await tester.pump();
        }
        await settle(tester);
        await shot(tester, '3-versus');
      });

      testWidgets('4 정답과 랭킹 등록', (tester) async {
        useDevice(tester);
        final history = [
          for (final guess in ['1234', '9031', '4790', '4752', '4725'])
            GuessRecord(guess: guess, result: NumberBaseball.judge('4725', guess)),
        ];
        await tester.pumpWidget(host(
          ResultScreen(
            summary: SoloSummary(
              tries: history.length,
              answer: '4725',
              elapsed: const Duration(minutes: 1, seconds: 48),
              history: history,
              gameId: '00000000-0000-0000-0000-000000000001',
            ),
          ),
          api: FakeServer().api,
        ));
        await settle(tester);
        final field = find.descendant(
          of: find.byType(RankingForm),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'KIM');
        await settle(tester);
        // 커서·키보드 포커스 없이, 화면 맨 위(4S 달성!)부터 보이게 찍는다.
        FocusManager.instance.primaryFocus?.unfocus();
        tester
            .state<ScrollableState>(find.descendant(
              of: find.byKey(const Key('result-scroll')),
              matching: find.byType(Scrollable),
            ))
            .position
            .jumpTo(0);
        await settle(tester);
        await shot(tester, '4-result');
      });

      testWidgets('5 랭킹', (tester) async {
        useDevice(tester);
        final server = FakeServer();
        server.rankings.addAll([
          _rank(1, 'ACE', 4, 52),
          _rank(2, 'JAY', 4, 71),
          _rank(3, 'SKY', 5, 48),
          _rank(4, 'KIM', 5, 66),
          _rank(5, 'MVP', 5, 93),
          _rank(6, 'LEE', 6, 57),
          _rank(7, 'HAN', 6, 84),
          _rank(8, 'BOB', 6, 112),
          _rank(9, 'SON', 7, 75),
          _rank(10, 'YOO', 7, 101),
          _rank(11, 'CHO', 8, 69),
          _rank(12, 'PAK', 8, 130),
          _rank(13, 'JUN', 9, 88),
        ]);
        await tester.pumpWidget(host(const RankingScreen(), api: server.api));
        await settle(tester);
        await shot(tester, '5-ranking');
      });

      testWidgets('6 친구 초대', (tester) async {
        useDevice(tester);
        final server = FakeServer();
        await tester.pumpWidget(host(
          const VersusRoomScreen(code: 'K7Q2', name: 'KIM'),
          api: server.api,
        ));
        await settle(tester);
        server.sockets.last
          ..serverSend({'type': 'welcome', 'playerId': 'p1'})
          ..serverSend(versusState(myName: 'KIM'));
        // 대기 중 표시가 계속 돌아서 pumpAndSettle 대신 시간만 흘려보낸다.
        await settle(tester);
        await shot(tester, '6-invite');
      });
    });
  }
}
