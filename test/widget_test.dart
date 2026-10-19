import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/game/solo_game.dart';
import 'package:four_s_challenge/screens/solo_play_screen.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

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

  testWidgets('홈 화면에서 혼자 하기로 들어간다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const FourSApp());

    expect(find.text('4S 챌린지'), findsOneWidget);
    expect(find.text('숫자야구'), findsOneWidget);

    await tester.tap(find.text('혼자 하기'));
    await tester.pumpAndSettle();

    expect(find.text('혼자 하기 · 4자리'), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);
  });

  testWidgets('준비 중인 메뉴는 안내 메시지를 띄운다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const FourSApp());

    await tester.tap(find.text('친구와 대결'));
    await tester.pump();
    expect(find.text('친구와 대결은 준비 중이에요'), findsOneWidget);
  });

  testWidgets('추리하면 기록이 남고 4S면 결과 화면으로 간다', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SoloPlayScreen(game: SoloGame(secret: '4725')),
    ));

    await tapDigits(tester, '4729');
    await tester.tap(find.byKey(const Key('key-submit')));
    await tester.pump();

    expect(find.text('4729'), findsOneWidget);
    expect(find.text('3S'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);

    await tapDigits(tester, '4725');
    await tester.tap(find.byKey(const Key('key-submit')));
    await tester.pump();
    expect(find.text('4S'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('4S 달성!'), findsOneWidget);
    expect(find.text('2번 만에 맞혔어요'), findsOneWidget);
  });

  testWidgets('이미 입력한 숫자 키는 눌리지 않는다', (tester) async {
    usePhoneSize(tester);
    final game = SoloGame(secret: '4725');
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SoloPlayScreen(game: game),
    ));

    await tapDigits(tester, '1');
    final key = tester.widget<FilledButton>(find.byKey(const Key('key-1')));
    expect(key.onPressed, isNull);
    expect(game.input, ['1']);
  });
}
