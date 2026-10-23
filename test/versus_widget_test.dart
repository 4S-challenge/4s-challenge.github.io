import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/app.dart';
import 'package:four_s_challenge/screens/versus_room_screen.dart';
import 'package:four_s_challenge/share/link_sharer.dart';
import 'package:four_s_challenge/theme/app_theme.dart';

import 'support/fake_server.dart';
import 'support/fake_sharer.dart';

void main() {
  setUp(() {
    AppFonts.useGoogleFonts = false;
    linkSharer = FakeLinkSharer();
  });

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
  Future<FakeVersusSocket> openRoom(WidgetTester tester, FakeServer server, {bool watch = false}) async {
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
      builder: (_) => VersusRoomScreen(code: 'K7Q2', name: watch ? 'YOO' : 'AAA', watch: watch),
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
  });

  testWidgets('초대하기: 공유 창이 있으면 기기 공유 창으로 링크를 보낸다', (tester) async {
    final sharer = FakeLinkSharer(canShare: true);
    linkSharer = sharer;
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(tester, socket, versusState());

    expect(find.text('초대하기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('versus-invite')));
    await tester.pump();

    expect(sharer.calls, hasLength(1));
    expect(sharer.calls.single.url, 'https://4s-challenge.github.io/?room=K7Q2');
    expect(sharer.calls.single.text, contains('K7Q2'));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('초대하기: 공유 창이 없는 곳(PC·카카오톡 안 브라우저)은 링크 복사', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    linkSharer = FakeLinkSharer(canShare: false);
    final server = FakeServer();
    final socket = await openRoom(tester, server);
    await send(tester, socket, versusState());

    expect(find.text('링크 복사'), findsOneWidget);
    await tester.tap(find.byKey(const Key('versus-invite')));
    await tester.pump();

    expect(copied, contains('https://4s-challenge.github.io/?room=K7Q2'));
    expect(find.text('초대 링크를 복사했어요. 친구에게 붙여넣어 보내 주세요'), findsOneWidget);
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
    expect(find.text('내 차례! 숫자 4개를 골라 던지세요'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('versus-my-secret')), matching: find.text('1234')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('versus-flash')), findsNothing);
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
    expect(find.text('BBB 차례예요 · 기다리는 중'), findsOneWidget);
    expect(find.text('5687'), findsOneWidget); // 내 추리 기록표
    // 전광판: 방금 던진 숫자와 결과가 딱 떴다가
    final flash = find.byKey(const Key('versus-flash'));
    expect(flash, findsOneWidget);
    for (final d in ['5', '6', '8', '7']) {
      expect(find.descendant(of: flash, matching: find.text(d)), findsOneWidget);
    }
    expect(find.descendant(of: flash, matching: find.text('2S')), findsOneWidget);
    expect(find.descendant(of: flash, matching: find.text('2B')), findsOneWidget);
    // 잠시 뒤 남은 시간으로 돌아간다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(flash, findsNothing);
    expect(find.byKey(const Key('versus-timer')), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
    final key5 = tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('vkey-5')), matching: find.byType(FilledButton)),
    );
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
    // 다시 내 차례: 차례 안내가 바뀌고, 전광판에 상대가 던진 숫자와 결과가 뜬다.
    expect(find.text('내 차례! 숫자 4개를 골라 던지세요'), findsOneWidget);
    expect(find.text('BBB'), findsWidgets);
    for (final d in ['1', '2', '9', '0']) {
      expect(find.descendant(of: flash, matching: find.text(d)), findsOneWidget);
    }
    expect(find.descendant(of: flash, matching: find.text('2S')), findsOneWidget);
    await settle(tester); // 차례 알림 애니메이션

    await tester.tap(find.text('상대 추리'));
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
    expect(find.text('BBB 님의 숫자를 먼저 맞혔어요'), findsOneWidget);
    expect(find.textContaining('번 만에'), findsNothing);
    final winner = find.byKey(const Key('versus-winner'));
    for (final ch in ['A', 'A', 'A']) {
      expect(find.descendant(of: winner, matching: find.text(ch)), findsWidgets);
    }
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
    expect(find.text('BBB 님이 방을 나가서 이겼어요'), findsOneWidget);
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
    expect(server.requests, contains('GET /api/versus/rooms/K7Q2'));
    expect(server.sockets.single.uri.path, '/api/versus/rooms/K7Q2/ws');
    expect(server.sockets.single.uri.queryParameters.containsKey('watch'), isFalse);
  });

  group('관전', () {
    Future<void> openLobby(WidgetTester tester, FakeServer server) async {
      usePhoneSize(tester);
      await tester.pumpWidget(FourSApp(api: server.api, initialRoomCode: 'K7Q2'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('versus-name')), 'YOO');
      await tester.pump();
      await tester.tap(find.byKey(const Key('versus-join')));
      await settle(tester);
    }

    testWidgets('대결 중인 방이면 관전으로 들어갈지 묻고, 아니요면 들어가지 않는다', (tester) async {
      final server = FakeServer()
        ..roomPeek = {'full': true, 'players': ['KIM', 'LEE'], 'spectators': 2};
      await openLobby(tester, server);

      expect(find.byKey(const Key('versus-watch-dialog')), findsOneWidget);
      expect(find.text('이미 대결 중인 방이에요'), findsOneWidget);
      expect(find.text('지금은 관전으로만 들어갈 수 있어요.\n관전으로 들어갈까요?'), findsOneWidget);
      expect(find.text('KIM'), findsOneWidget);
      expect(find.text('LEE'), findsOneWidget);
      expect(find.text('관전 2명'), findsOneWidget);

      await tester.tap(find.text('아니요'));
      await settle(tester);
      expect(server.sockets, isEmpty);
      expect(find.byKey(const Key('versus-watch-dialog')), findsNothing);
    });

    testWidgets('관전하기를 누르면 관전자로 들어간다', (tester) async {
      final server = FakeServer()
        ..roomPeek = {'full': true, 'players': ['KIM', 'LEE'], 'spectators': 0};
      await openLobby(tester, server);
      await tester.tap(find.byKey(const Key('versus-watch-confirm')));
      await settle(tester);
      final socket = server.sockets.single;
      expect(socket.uri.queryParameters['watch'], '1');
      expect(socket.uri.queryParameters['name'], 'YOO');
    });

    testWidgets('없는 방이면 로비에서 바로 알려준다', (tester) async {
      final server = FakeServer()..roomPeek = null;
      await openLobby(tester, server);
      expect(find.text('없는 방이에요. 코드를 확인해 주세요'), findsOneWidget);
      expect(server.sockets, isEmpty);
    });

    testWidgets('관전 화면: 두 사람 기록과 함께 보는 사람, 키패드 없음, 바로 나가기', (tester) async {
      final server = FakeServer();
      final socket = await openRoom(tester, server, watch: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final spectators = [watcher('PAK'), watcher('YOO', me: true)];
      Map<String, Object?> state({List<Map<String, Object?>> leeGuesses = const []}) => versusState(
            phase: 'playing',
            spectator: true,
            turn: 0,
            serverNow: now,
            turnDeadline: now + 30000,
            myName: 'KIM',
            myGuesses: [g('1234', 0, 2)],
            opponent: versusOpponent(name: 'LEE', ready: true, guesses: leeGuesses),
            spectators: spectators,
          );
      await send(tester, socket, state());

      expect(find.text('관전 중 · K7Q2'), findsOneWidget);
      expect(find.text('KIM 차례'), findsOneWidget);
      expect(find.text('관전 중 · KIM 님이 숫자를 고르는 중'), findsOneWidget);
      expect(find.text('KIM의 추리'), findsOneWidget);
      expect(find.text('LEE의 추리'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('YOO (나)'), findsOneWidget);
      expect(find.text('PAK'), findsOneWidget);
      expect(find.byKey(const Key('vkey-1')), findsNothing);
      expect(find.byKey(const Key('versus-my-secret')), findsNothing);
      expect(find.text('내 차례'), findsNothing);

      // 누가 던지면 전광판에 이름과 숫자가 뜬다.
      await send(tester, socket, state(leeGuesses: [g('2890', 0, 3)]));
      final flash = find.byKey(const Key('versus-flash'));
      expect(find.descendant(of: flash, matching: find.text('LEE')), findsOneWidget);
      expect(find.descendant(of: flash, matching: find.text('3B')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // 관전 그만하기는 확인 없이 바로 나간다.
      await tester.tap(find.byKey(const Key('versus-watch-leave')));
      await settle(tester);
      expect(socket.sent.last, {'type': 'leave'});
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('관전 결과: 승자와 두 사람의 숫자를 보여주고 한 판 더는 없다', (tester) async {
      final server = FakeServer();
      final socket = await openRoom(tester, server, watch: true);
      await send(
        tester,
        socket,
        versusState(
          phase: 'finished',
          spectator: true,
          winner: 1,
          endReason: 'solved',
          myName: 'KIM',
          mySecret: '1234',
          myGuesses: [g('5687', 2, 2)],
          opponent: versusOpponent(name: 'LEE', secret: '5678', guesses: [g('1234', 4, 0)]),
          spectators: [watcher('YOO', me: true)],
        ),
      );
      expect(find.text('LEE 승리!'), findsOneWidget);
      expect(find.text('LEE 님이 KIM 님의 숫자를 먼저 맞혔어요'), findsOneWidget);
      expect(find.text('KIM의 숫자'), findsOneWidget);
      expect(find.text('LEE의 숫자'), findsOneWidget);
      expect(find.text('5678'), findsOneWidget);
      expect(find.byKey(const Key('versus-rematch')), findsNothing);
      expect(find.byKey(const Key('versus-watch-leave')), findsOneWidget);
    });

    testWidgets('선수 화면: 눈 버튼에 관전자 수, 누르면 목록, 새 관전자는 알림', (tester) async {
      final server = FakeServer();
      final socket = await openRoom(tester, server);
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, Object?> state(List<Map<String, Object?>> spectators) => versusState(
            phase: 'playing',
            turn: 1,
            serverNow: now,
            turnDeadline: now + 30000,
            mySecret: '1234',
            opponent: versusOpponent(ready: true),
            spectators: spectators,
          );
      await send(tester, socket, state([]));
      expect(find.byKey(const Key('versus-spectators')), findsNothing);

      await send(tester, socket, state([watcher('PAK', since: now - 180000)]));
      await tester.pump();
      expect(find.text('PAK 님이 관전을 시작했어요'), findsOneWidget);
      final eye = find.byKey(const Key('versus-spectators'));
      expect(find.descendant(of: eye, matching: find.text('1')), findsOneWidget);

      await tester.tap(eye);
      await settle(tester);
      final sheet = find.byKey(const Key('versus-spectator-sheet'));
      expect(find.descendant(of: sheet, matching: find.text('PAK')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('3분 전부터')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('1명')), findsOneWidget);
    });
  });
}
