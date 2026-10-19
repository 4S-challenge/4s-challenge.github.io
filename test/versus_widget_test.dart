import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/screens/versus_room_screen.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

import 'support/fake_server.dart';

void main() {
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

  /// 홈 위에 대결방 화면을 띄우고, 앱이 연 가짜 연결을 돌려준다.
  Future<FakeVersusSocket> openRoom(WidgetTester tester, FakeServer server) async {
    usePhoneSize(tester);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ApiScope(
      api: server.api,
      child: MaterialApp(
        navigatorKey: nav,
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('HOME')),
      ),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const VersusRoomScreen(code: 'K7Q2', name: 'AAA'),
    ));
    await settle(tester);
    final socket = server.sockets.last;
    socket.serverSend({'type': 'welcome', 'playerId': 'p1'});
    await tester.pump();
    return socket;
  }

  Future<void> send(WidgetTester tester, FakeVersusSocket socket, Map<String, Object?> msg) async {
    socket.serverSend(msg);
    await tester.pump();
    await tester.pump();
  }

  Future<void> typeDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(Key('vkey-$d')));
      await tester.pump();
    }
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('vkey-submit')));

  testWidgets('대기: 방 코드를 보여주고 상대를 기다린다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    expect(socket.uri.toString(), 'wss://api.example.test/api/versus/rooms/K7Q2/ws?name=AAA');

    await send(tester, socket, versusState());
    final code = find.byKey(const Key('versus-room-code'));
    for (final ch in ['K', '7', 'Q', '2']) {
      expect(find.descendant(of: code, matching: find.text(ch)), findsOneWidget);
    }
    expect(find.text('상대를 기다리는 중…'), findsOneWidget);
    expect(find.text('링크 복사'), findsOneWidget);
  });

  testWidgets('숫자 정하기: 네 자리를 골라 정하면 서버로 보낸다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(tester, socket, versusState(phase: 'setting', opponent: versusOpponent()));

    expect(find.text('상대가 맞힐 내 비밀 숫자를 정하세요'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await typeDigits(tester, '1123');
    await typeDigits(tester, '4');
    expect(submitButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('vkey-submit')));
    await tester.pump();
    expect(socket.sent.last, {'type': 'setSecret', 'secret': '1234'});

    await send(
      tester,
      socket,
      versusState(phase: 'setting', mySecret: '1234', opponent: versusOpponent()),
    );
    expect(find.text('상대가 숫자를 정하는 중…'), findsOneWidget);
    expect(find.text('정하는 중'), findsOneWidget); // 상대 상태
  });

  testWidgets('대결: 내 차례에만 던질 수 있고, 던지면 입력칸이 비워진다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    final now = DateTime.now().millisecondsSinceEpoch;
    await send(
      tester,
      socket,
      versusState(
        phase: 'playing',
        turn: 0,
        serverNow: now,
        turnDeadline: now + 30000,
        mySecret: '1234',
        opponent: versusOpponent(ready: true),
      ),
    );

    expect(find.text('내 차례'), findsOneWidget);
    final timer = tester.widget<Text>(find.byKey(const Key('versus-timer')));
    expect(timer.data, matches(RegExp(r'^0:(30|29)$')));

    await typeDigits(tester, '5687');
    await tester.tap(find.byKey(const Key('vkey-submit')));
    await tester.pump();
    expect(socket.sent.last, {'type': 'guess', 'guess': '5687'});

    await send(
      tester,
      socket,
      versusState(
        phase: 'playing',
        turn: 1,
        serverNow: now,
        turnDeadline: now + 30000,
        mySecret: '1234',
        myGuesses: [g('5687', 2, 2)],
        opponent: versusOpponent(ready: true),
      ),
    );
    expect(find.text('상대 차례'), findsWidgets);
    expect(find.text('5687'), findsOneWidget);
    expect(find.text('2S'), findsOneWidget);
    expect(find.text('2B'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
    final key5 = tester.widget<FilledButton>(find.byKey(const Key('vkey-5')));
    expect(key5.onPressed, isNull);

    // 상대가 내 숫자에 던진 기록 보기
    await send(
      tester,
      socket,
      versusState(
        phase: 'playing',
        turn: 0,
        serverNow: now,
        turnDeadline: now + 30000,
        mySecret: '1234',
        myGuesses: [g('5687', 2, 2)],
        opponent: versusOpponent(ready: true, guesses: [g('1290', 2, 0)]),
      ),
    );
    await tester.tap(find.text('상대 추리 1'));
    await tester.pump();
    expect(find.text('1290'), findsOneWidget);
  });

  testWidgets('결과: 이기면 승리, 한 판 더를 보낼 수 있다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(
      tester,
      socket,
      versusState(
        phase: 'finished',
        winner: 0,
        endReason: 'solved',
        mySecret: '1234',
        myGuesses: [g('5687', 2, 2), g('5678', 4, 0)],
        opponent: versusOpponent(ready: true, secret: '5678', guesses: [g('1290', 2, 0)]),
      ),
    );

    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('2번 만에 상대 숫자를 맞혔어요'), findsOneWidget);
    expect(find.text('5678'), findsWidgets);

    await tester.tap(find.byKey(const Key('versus-rematch')));
    await tester.pump();
    expect(socket.sent.last, {'type': 'rematch'});

    await send(
      tester,
      socket,
      versusState(
        phase: 'finished',
        winner: 0,
        endReason: 'solved',
        myRematch: true,
        opponent: versusOpponent(secret: '5678'),
      ),
    );
    expect(find.text('상대를 기다리는 중…'), findsOneWidget);
  });

  testWidgets('결과: 상대가 나가면 기권승, 한 판 더는 불가', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(
      tester,
      socket,
      versusState(
        phase: 'finished',
        winner: 0,
        endReason: 'forfeit',
        opponent: versusOpponent(left: true, connected: false),
      ),
    );
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('상대가 방을 나가서 이겼어요'), findsOneWidget);
    expect(find.text('상대가 나갔어요'), findsOneWidget);
  });

  testWidgets('대결 중 X를 누르면 확인 후 기권하고 나간다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(
      tester,
      socket,
      versusState(phase: 'playing', turn: 1, mySecret: '1234', opponent: versusOpponent(ready: true)),
    );

    await tester.tap(find.byKey(const Key('versus-close')));
    await settle(tester);
    expect(find.text('대결 중에 나가면 기권패로 처리돼요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('versus-leave-confirm')));
    await settle(tester);
    expect(socket.sent.last, {'type': 'leave'});
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('들어갈 수 없는 방이면 안내하고 돌아갈 수 있다', (tester) async {
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(tester, socket, {
      'type': 'error',
      'message': '이미 대결이 시작된 방이에요',
      'fatal': true,
    });
    expect(find.text('이미 대결이 시작된 방이에요'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
    await settle(tester);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('홈 → 친구와 대결 → 방 만들기', (tester) async {
    usePhoneSize(tester);
    final server = FakeServer()..roomCode = 'ZX9P';
    await tester.pumpWidget(FourSApp(api: server.api));

    await tester.tap(find.text('친구와 대결'));
    await tester.pumpAndSettle();
    expect(find.text('방 만들기'), findsOneWidget);

    final create = find.descendant(
      of: find.byKey(const Key('versus-create')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('versus-name')), 'abc');
    await tester.pump();
    await tester.tap(find.byKey(const Key('versus-create')));
    await settle(tester);

    expect(server.requests, contains('POST /api/versus/rooms'));
    final socket = server.sockets.single;
    expect(socket.uri.path, '/api/versus/rooms/ZX9P/ws');
    expect(socket.uri.queryParameters['name'], 'ABC');
    expect(find.text('친구와 대결 · ZX9P'), findsOneWidget);
  });

  testWidgets('초대 링크로 열면 방 코드가 채워진 대결 화면이 열린다', (tester) async {
    usePhoneSize(tester);
    final server = FakeServer();
    await tester.pumpWidget(FourSApp(api: server.api, initialRoomCode: 'K7Q2'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(of: find.byKey(const Key('versus-code')), matching: find.byType(TextField)),
    );
    expect(field.controller!.text, 'K7Q2');

    await tester.enterText(find.byKey(const Key('versus-name')), 'XYZ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('versus-join')));
    await settle(tester);
    expect(server.sockets.single.uri.path, '/api/versus/rooms/K7Q2/ws');
  });
}
