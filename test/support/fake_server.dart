import 'dart:convert';

import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:four_s_challenge/game/game_logic.dart';
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

  FourSApi get api => FourSApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: MockClient(_handle),
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
