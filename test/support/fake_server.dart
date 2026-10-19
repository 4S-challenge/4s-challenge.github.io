import 'dart:async';
import 'dart:convert';

import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/game/game_logic.dart';
import 'package:four_s_challenge/versus/versus_socket.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 테스트용 가짜 랭킹 서버. Cloudflare Worker와 같은 규칙으로 응답한다.
class FakeServer {
  FakeServer({this.secret = '4725', this.durationMs = 95000});

  final String secret;
  final int durationMs;

  /// true면 모든 요청이 네트워크 오류로 실패한다.
  bool offline = false;

  final Map<String, ({int tries, bool solved, bool ranked})> games = {};
  final List<Map<String, Object>> rankings = [];
  final List<String> requests = [];
  int _nextGame = 0;

  /// 방 만들기 요청에 돌려줄 방 코드.
  String roomCode = 'K7Q2';

  /// 앱이 연 대결방 연결들.
  final List<FakeVersusSocket> sockets = [];

  FourSApi get api => FourSApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: MockClient(_handle),
        socketConnector: (uri) async {
          if (offline) throw Exception('offline');
          final socket = FakeVersusSocket(uri);
          sockets.add(socket);
          return socket;
        },
      );

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Future<http.Response> _handle(http.Request req) async {
    if (offline) throw http.ClientException('offline');
    final key = '${req.method} ${req.url.path}';
    requests.add(key);
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(req.body) as Map<String, dynamic>;

    switch (key) {
      case 'POST /api/solo/start':
        final id = '00000000-0000-0000-0000-${(_nextGame++).toString().padLeft(12, '0')}';
        games[id] = (tries: 0, solved: false, ranked: false);
        return _json({'gameId': id}, 201);

      case 'POST /api/solo/guess':
        final id = body['gameId'] as String;
        final game = games[id];
        if (game == null) return _json({'error': '게임을 찾을 수 없어요'}, 404);
        if (game.solved) return _json({'error': '이미 끝난 게임이에요'}, 409);
        final r = NumberBaseball.judge(secret, body['guess'] as String);
        final tries = game.tries + 1;
        games[id] = (tries: tries, solved: r.isWin, ranked: false);
        return _json({
          'strikes': r.strikes,
          'balls': r.balls,
          'tries': tries,
          'solved': r.isWin,
          'durationMs': r.isWin ? durationMs : null,
        });

      case 'POST /api/rankings':
        final id = body['gameId'] as String;
        final initials = body['initials'] as String;
        final game = games[id];
        if (game == null) return _json({'error': '게임을 찾을 수 없어요'}, 404);
        if (!RegExp(r'^[A-Z]{3}$').hasMatch(initials)) {
          return _json({'error': '영문 대문자 3글자를 입력해 주세요'}, 400);
        }
        if (!game.solved) {
          return _json({'error': '아직 정답을 맞히지 않은 게임이에요'}, 409);
        }
        if (game.ranked) {
          return _json({'error': '이미 랭킹에 등록한 게임이에요'}, 409);
        }
        games[id] = (tries: game.tries, solved: true, ranked: true);
        final entry = <String, Object>{
          'id': rankings.length + 1,
          'initials': initials,
          'tries': game.tries,
          'durationMs': durationMs,
          'createdAt': 1792400000000,
        };
        rankings.add(entry);
        final rank = rankings
                .where((e) => (e['tries'] as int) < game.tries)
                .length +
            1;
        return _json({
          'entry': {...entry, 'rank': rank},
        }, 201);

      case 'POST /api/versus/rooms':
        return _json({'code': roomCode}, 201);

      case 'GET /api/rankings':
        final sorted = [...rankings]
          ..sort((a, b) => (a['tries'] as int).compareTo(b['tries'] as int));
        return _json({
          'entries': [
            for (var i = 0; i < sorted.length; i++) {...sorted[i], 'rank': i + 1},
          ],
        });
    }
    return _json({'error': '없는 주소예요'}, 404);
  }
}

/// 테스트용 대결방 연결. [serverSend]로 서버 메시지를 흘려보내고 [sent]로 앱이 보낸 것을 본다.
class FakeVersusSocket implements VersusSocket {
  FakeVersusSocket(this.uri);

  final Uri uri;
  final _controller = StreamController<String>();
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String data) {
    if (data == 'ping') return;
    sent.add(jsonDecode(data) as Map<String, dynamic>);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }

  void serverSend(Map<String, Object?> message) => _controller.add(jsonEncode(message));

  /// 서버 쪽에서 연결이 끊긴 것처럼.
  Future<void> drop() => close();
}

/// 서버 state 메시지를 쉽게 만든다.
Map<String, Object?> versusState({
  String phase = 'waiting',
  int you = 0,
  int? turn,
  int? turnDeadline,
  int serverNow = 1792400000000,
  int round = 1,
  int? winner,
  String? endReason,
  Map<String, Object?>? lastEvent,
  String myName = 'AAA',
  String? mySecret,
  List<Map<String, Object?>> myGuesses = const [],
  bool myRematch = false,
  Map<String, Object?>? opponent,
}) =>
    {
      'type': 'state',
      'code': 'K7Q2',
      'phase': phase,
      'round': round,
      'serverNow': serverNow,
      'you': you,
      'turn': turn,
      'turnDeadline': turnDeadline,
      'firstSeat': 0,
      'winner': winner,
      'endReason': endReason,
      'lastEvent': lastEvent,
      'me': {
        'name': myName,
        'secret': mySecret,
        'guesses': myGuesses,
        'rematch': myRematch,
      },
      'opponent': opponent,
    };

Map<String, Object?> versusOpponent({
  String name = 'BBB',
  bool connected = true,
  bool left = false,
  bool ready = false,
  bool rematch = false,
  List<Map<String, Object?>> guesses = const [],
  String? secret,
}) =>
    {
      'name': name,
      'connected': connected,
      'left': left,
      'ready': ready,
      'rematch': rematch,
      'guesses': guesses,
      'secret': secret,
    };

Map<String, Object?> g(String guess, int strikes, int balls) =>
    {'guess': guess, 'strikes': strikes, 'balls': balls};
