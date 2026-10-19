import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/versus/versus_models.dart';
import 'package:four_s_challenge/versus/versus_session.dart';

import 'support/fake_server.dart';

const serverNow = 1792400000000;

void main() {
  late FakeServer server;
  late List<String> notices;

  VersusSession newSession() {
    final api = server.api;
    final session = VersusSession(
      code: 'K7Q2',
      name: 'AAA',
      socketUri: (playerId) => api.roomSocketUri('K7Q2', name: 'AAA', playerId: playerId),
      connector: api.socketConnector,
      // 기기 시계가 서버보다 5초 느린 상황
      clock: () => DateTime.fromMillisecondsSinceEpoch(serverNow - 5000),
    );
    notices = [];
    session.notices.listen(notices.add);
    return session;
  }

  setUp(() => server = FakeServer());

  testWidgets('접속해서 상태를 받고, 서버 시계로 남은 시간을 계산한다', (tester) async {
    final session = newSession();
    await session.start();
    await tester.pump();

    final socket = server.sockets.single;
    expect(socket.uri.toString(), 'wss://api.example.test/api/versus/rooms/K7Q2/ws?name=AAA');
    expect(session.status, VersusStatus.connecting);

    socket.serverSend({'type': 'welcome', 'playerId': 'p1'});
    socket.serverSend(versusState(
      phase: 'playing',
      turn: 0,
      turnDeadline: serverNow + 30000,
      mySecret: '1234',
      opponent: versusOpponent(ready: true),
    ));
    await tester.pump();

    expect(session.status, VersusStatus.open);
    expect(session.playerId, 'p1');
    expect(session.snapshot!.phase, VersusPhase.playing);
    expect(session.snapshot!.myTurn, isTrue);
    expect(session.remaining, const Duration(seconds: 30));

    session.guess('5678');
    session.setSecret('1234');
    expect(socket.sent, [
      {'type': 'guess', 'guess': '5678'},
      {'type': 'setSecret', 'secret': '1234'},
    ]);

    socket.serverSend({'type': 'error', 'message': '상대 차례예요', 'fatal': false});
    await tester.pump();
    expect(notices, ['상대 차례예요']);
    expect(session.fatalError, isNull);

    session.dispose();
  });

  testWidgets('시간 초과를 알려준다 (처음 받은 상태의 예전 일은 제외)', (tester) async {
    final session = newSession();
    await session.start();
    await tester.pump();
    final socket = server.sockets.single;

    socket.serverSend(versusState(
      phase: 'playing',
      turn: 1,
      lastEvent: {'type': 'timeout', 'seat': 0, 'at': 1},
      opponent: versusOpponent(),
    ));
    await tester.pump();
    expect(notices, isEmpty);

    socket.serverSend(versusState(
      phase: 'playing',
      turn: 0,
      lastEvent: {'type': 'timeout', 'seat': 1, 'at': 2},
      opponent: versusOpponent(),
    ));
    await tester.pump();
    expect(notices, ['상대가 시간을 넘겨 내 차례예요']);

    socket.serverSend(versusState(
      phase: 'playing',
      turn: 1,
      lastEvent: {'type': 'timeout', 'seat': 0, 'at': 3},
      opponent: versusOpponent(),
    ));
    await tester.pump();
    expect(notices.last, '시간 초과! 상대 차례로 넘어갔어요');

    session.dispose();
  });

  testWidgets('연결이 끊기면 같은 playerId로 다시 연결한다', (tester) async {
    final session = newSession();
    await session.start();
    await tester.pump();
    final first = server.sockets.single;
    first.serverSend({'type': 'welcome', 'playerId': 'p1'});
    first.serverSend(versusState(phase: 'setting', opponent: versusOpponent()));
    await tester.pump();

    await first.drop();
    await tester.pump();
    expect(session.status, VersusStatus.reconnecting);
    expect(session.snapshot, isNotNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(server.sockets, hasLength(2));
    expect(server.sockets.last.uri.queryParameters['playerId'], 'p1');

    server.sockets.last.serverSend({'type': 'welcome', 'playerId': 'p1'});
    await tester.pump();
    expect(session.status, VersusStatus.open);

    session.dispose();
  });

  testWidgets('들어갈 수 없는 방이면 끝낸다', (tester) async {
    final session = newSession();
    await session.start();
    await tester.pump();
    server.sockets.single.serverSend({
      'type': 'error',
      'message': '없는 방이에요. 코드를 확인해 주세요',
      'fatal': true,
    });
    await tester.pump();

    expect(session.fatalError, '없는 방이에요. 코드를 확인해 주세요');
    expect(session.status, VersusStatus.closed);
    expect(server.sockets.single.closed, isTrue);

    // 다시 연결하지 않는다.
    await tester.pump(const Duration(seconds: 5));
    expect(server.sockets, hasLength(1));

    session.dispose();
  });

  testWidgets('서버에 계속 연결할 수 없으면 포기한다', (tester) async {
    server.offline = true;
    final session = newSession();
    await session.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(session.fatalError, '서버에 연결할 수 없어요');
    session.dispose();
  });

  testWidgets('나가기는 leave를 보내고 다시 연결하지 않는다', (tester) async {
    final session = newSession();
    await session.start();
    await tester.pump();
    final socket = server.sockets.single;
    socket.serverSend({'type': 'welcome', 'playerId': 'p1'});
    await tester.pump();

    session.leave();
    expect(socket.sent.last, {'type': 'leave'});
    expect(socket.closed, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(server.sockets, hasLength(1));

    session.dispose();
  });
}
