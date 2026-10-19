import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/invite_link.dart';
import 'package:four_s_challenge/screens/ranking_screen.dart';
import 'package:four_s_challenge/screens/versus_lobby_screen.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

import 'support/fake_server.dart';

void main() {
  group('roomCodeFromUri', () {
    test('초대 링크에서 방 코드를 꺼낸다', () {
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=K7Q2')), 'K7Q2');
    });

    test('소문자·공백은 정리한다', () {
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=%20k7q2%20')), 'K7Q2');
    });

    test('방 코드가 없거나 형식이 틀리면 null', () {
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/')), isNull);
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=')), isNull);
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=K7Q')), isNull);
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=K7Q2X')), isNull);
      expect(roomCodeFromUri(Uri.parse('https://4s-challenge.github.io/?room=K7-2')), isNull);
    });
  });

  group('앱으로 들어온 초대 링크', () {
    setUp(() => AppFonts.useGoogleFonts = false);

    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// 로딩 표시처럼 계속 움직이는 화면이 있어 pumpAndSettle 대신 시간만 흘려보낸다.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    String codeFieldText(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(of: find.byKey(const Key('versus-code')), matching: find.byType(EditableText)),
        )
        .controller
        .text;

    testWidgets('링크를 열면 방 코드가 채워진 대결 화면이 열린다', (tester) async {
      usePhoneSize(tester);
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await tester.pumpWidget(FourSApp(api: FakeServer().api, inviteLinks: links.stream));

      links.add(Uri.parse('https://4s-challenge.github.io/?room=k7q2'));
      await settle(tester);

      expect(find.byType(VersusLobbyScreen), findsOneWidget);
      expect(codeFieldText(tester), 'K7Q2');
    });

    testWidgets('다른 화면을 보고 있어도 대결 화면으로 바꿔 연다', (tester) async {
      usePhoneSize(tester);
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await tester.pumpWidget(FourSApp(api: FakeServer().api, inviteLinks: links.stream));

      await tester.tap(find.text('랭킹'));
      await settle(tester);
      expect(find.byType(RankingScreen), findsOneWidget);

      links.add(Uri.parse('https://4s-challenge.github.io/?room=AB23'));
      // 랭킹 화면이 닫히는 전환까지 기다린다.
      await settle(tester);
      await settle(tester);

      expect(find.byType(RankingScreen), findsNothing);
      expect(find.byType(VersusLobbyScreen), findsOneWidget);
      expect(codeFieldText(tester), 'AB23');
    });

    testWidgets('방 코드가 없는 링크는 무시한다', (tester) async {
      usePhoneSize(tester);
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await tester.pumpWidget(FourSApp(api: FakeServer().api, inviteLinks: links.stream));

      links.add(Uri.parse('https://4s-challenge.github.io/'));
      await settle(tester);

      expect(find.byType(VersusLobbyScreen), findsNothing);
      expect(find.text('4S 챌린지'), findsOneWidget);
    });
  });
}
