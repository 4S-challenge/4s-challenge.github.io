import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/game/solo_game.dart';
import 'package:four_s_challenge/screens/solo_play_screen.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

import 'support/fake_server.dart';

void main() {
  setUp(() => AppFonts.useGoogleFonts = false);

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(Key('key-$d')));
      await tester.pump();
    }
  }

  Future<void> throwGuess(WidgetTester tester, String digits) async {
    await tapDigits(tester, digits);
    await tester.tap(find.byKey(const Key('key-submit')));
    await tester.pump();
    await tester.pump();
  }

  Widget host(Widget home, {FourSApi? api}) => ApiScope(
        api: api,
        child: MaterialApp(theme: buildAppTheme(), home: home),
      );

  testWidgets('홈 화면에서 혼자 하기로 들어간다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const FourSApp());

    expect(find.text('4S 챌린지'), findsOneWidget);
    expect(find.text('숫자야구'), findsOneWidget);

    await tester.tap(find.text('혼자 하기'));
    await tester.pumpAndSettle();

    expect(find.text('혼자 하기 · 4자리'), findsOneWidget);
    expect(find.text('0회'), findsOneWidget);
    expect(find.text('오프라인 모드 · 랭킹 등록 불가'), findsOneWidget);
  });

  testWidgets('준비 중인 메뉴는 안내 메시지를 띄운다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const FourSApp());

    await tester.tap(find.text('친구와 대결'));
    await tester.pump();
    expect(find.text('친구와 대결은 준비 중이에요'), findsOneWidget);
  });

  testWidgets('오프라인: 10번을 넘겨도 계속하고 총 시도 횟수를 보여준다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(SoloPlayScreen(game: SoloGame(secret: '4725'))));

    for (var i = 0; i < 11; i++) {
      await throwGuess(tester, '1234');
    }
    expect(find.text('11회'), findsOneWidget);

    // 기록이 길어지면 마지막 줄로 자동 스크롤된다.
    await throwGuess(tester, '4729');
    await tester.pumpAndSettle();
    expect(find.text('3S'), findsOneWidget);

    await throwGuess(tester, '4725');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('4S 달성!'), findsOneWidget);
    expect(find.text('13번 만에 맞혔어요'), findsOneWidget);
    expect(find.text('오프라인으로 플레이한 게임은 랭킹에 등록할 수 없어요'), findsOneWidget);
  });

  testWidgets('결과 화면에서 이번 판 기록을 보고, 크게 보기 팝업을 X로 닫는다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(SoloPlayScreen(game: SoloGame(secret: '4725'))));

    await throwGuess(tester, '1234');
    await throwGuess(tester, '4790');
    await throwGuess(tester, '4729');
    await throwGuess(tester, '4725');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 결과 화면 안의 기록 목록
    final inline = find.byKey(const Key('history-inline'));
    await tester.ensureVisible(inline);
    await tester.pumpAndSettle();
    expect(find.text('이번 판 기록'), findsOneWidget);
    for (final guess in ['1234', '4790', '4729']) {
      expect(find.descendant(of: inline, matching: find.text(guess)), findsOneWidget);
    }
    expect(find.descendant(of: inline, matching: find.text('2B')), findsOneWidget);
    expect(find.descendant(of: inline, matching: find.text('2S')), findsOneWidget);
    expect(find.descendant(of: inline, matching: find.text('3S')), findsOneWidget);
    expect(find.descendant(of: inline, matching: find.text('4S')), findsOneWidget);

    // 크게 보기 → 기록만 보이는 팝업
    await tester.tap(find.byKey(const Key('history-expand')));
    await tester.pumpAndSettle();
    final full = find.byKey(const Key('history-full'));
    expect(full, findsOneWidget);
    expect(find.text('이번 판 기록 · 4회'), findsOneWidget);
    expect(find.descendant(of: full, matching: find.text('4725')), findsOneWidget);
    expect(find.descendant(of: full, matching: find.text('3S')), findsOneWidget);

    // 오른쪽 위 X로 닫기
    final close = find.byKey(const Key('history-close'));
    expect(
      tester.getCenter(close).dx,
      greaterThan(tester.getCenter(full).dx),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(full, findsNothing);
    expect(find.text('4S 달성!'), findsOneWidget);
  });

  testWidgets('결과 화면 버튼은 아래에 고정되어 스크롤 없이 보인다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(SoloPlayScreen(game: SoloGame(secret: '4725'))));
    for (var i = 0; i < 8; i++) {
      await throwGuess(tester, '1234');
    }
    await throwGuess(tester, '4725');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final actions = find.byKey(const Key('result-actions'));
    expect(tester.getBottomLeft(actions).dy, closeTo(screenHeight, 1));
    for (final label in ['한 판 더', '결과 복사', '홈으로']) {
      expect(tester.getBottomLeft(find.text(label)).dy, lessThan(screenHeight));
    }

    // 내용을 끝까지 스크롤해도 버튼 위치는 그대로다.
    final before = tester.getTopLeft(find.text('한 판 더'));
    await tester.drag(find.byKey(const Key('result-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('한 판 더')), before);

    // 스크롤하지 않고 바로 누를 수 있다.
    await tester.tap(find.text('한 판 더'));
    await tester.pumpAndSettle();
    expect(find.text('4S 달성!'), findsNothing);
    expect(find.text('혼자 하기 · 4자리'), findsOneWidget);
  });

  testWidgets('이미 입력한 숫자 키는 눌리지 않는다', (tester) async {
    usePhoneSize(tester);
    final game = SoloGame(secret: '4725');
    await tester.pumpWidget(host(SoloPlayScreen(game: game)));

    await tapDigits(tester, '1');
    final key = tester.widget<FilledButton>(find.byKey(const Key('key-1')));
    expect(key.onPressed, isNull);
    expect(game.input, ['1']);
  });

  testWidgets('온라인: 맞히면 이니셜 3글자로 랭킹에 등록한다', (tester) async {
    usePhoneSize(tester);
    final server = FakeServer(secret: '4725');
    final api = server.api;
    await tester.pumpWidget(host(const SoloPlayScreen(), api: api));
    await tester.pumpAndSettle();

    expect(find.text('오프라인 모드 · 랭킹 등록 불가'), findsNothing);

    await throwGuess(tester, '1234');
    await tester.pumpAndSettle();
    await throwGuess(tester, '4725');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('2번 만에 맞혔어요'), findsOneWidget);
    expect(find.text('랭킹에 이름 남기기'), findsOneWidget);

    // 소문자·숫자는 걸러지고 대문자 3글자만 남는다.
    await tester.enterText(find.byKey(const Key('initials-field')), 'ab1cd');
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('initials-field')));
    expect(field.controller!.text, 'ABC');

    await tester.ensureVisible(find.byKey(const Key('rank-submit')));
    await tester.tap(find.byKey(const Key('rank-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registered-rank')), findsOneWidget);
    expect(find.text('1위'), findsOneWidget);
    expect(server.rankings.single['initials'], 'ABC');

    await tester.ensureVisible(find.text('랭킹 보기'));
    await tester.tap(find.text('랭킹 보기'));
    await tester.pumpAndSettle();
    expect(find.text('랭킹'), findsOneWidget);
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('2회'), findsOneWidget);
  });

  testWidgets('랭킹 등록 버튼은 3글자가 되어야 눌린다', (tester) async {
    usePhoneSize(tester);
    final server = FakeServer(secret: '4725');
    await tester.pumpWidget(host(const SoloPlayScreen(), api: server.api));
    await tester.pumpAndSettle();
    await throwGuess(tester, '4725');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('initials-field')), 'AB');
    await tester.pump();
    final button = find.descendant(
      of: find.byKey(const Key('rank-submit')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('initials-field')), 'ABZ');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('홈의 랭킹 버튼: 서버가 없으면 준비 중 안내', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const FourSApp());
    await tester.tap(find.text('랭킹'));
    await tester.pumpAndSettle();
    expect(find.text('랭킹 서버를 준비 중이에요'), findsOneWidget);
  });

  testWidgets('홈의 랭킹 버튼: 서버 목록을 보여준다', (tester) async {
    usePhoneSize(tester);
    final server = FakeServer();
    server.rankings.addAll([
      {'id': 1, 'initials': 'KIM', 'tries': 5, 'durationMs': 80000, 'createdAt': 1792400000000},
      {'id': 2, 'initials': 'LEE', 'tries': 3, 'durationMs': 120000, 'createdAt': 1792400000000},
    ]);
    await tester.pumpWidget(FourSApp(api: server.api));
    await tester.tap(find.text('랭킹'));
    await tester.pumpAndSettle();

    expect(find.text('LEE'), findsOneWidget);
    expect(find.text('KIM'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('LEE')).dy,
      lessThan(tester.getTopLeft(find.text('KIM')).dy),
    );
  });
}
