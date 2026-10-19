import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/api/four_s_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_server.dart';

void main() {
  test('랭킹 등록과 조회', () async {
    final server = FakeServer();
    final api = server.api;

    final gameId = await api.startSolo();
    await api.guess(gameId, '1234');
    final win = await api.guess(gameId, '4725');
    expect(win.solved, isTrue);
    expect(win.tries, 2);
    expect(win.duration, const Duration(milliseconds: 95000));

    final entry = await api.submitRanking(gameId, 'ABC');
    expect(entry.rank, 1);
    expect(entry.initials, 'ABC');
    expect(entry.tries, 2);

    final list = await api.rankings();
    expect(list.single.initials, 'ABC');
  });

  test('서버 오류 메시지를 그대로 전달한다', () async {
    final server = FakeServer();
    final api = server.api;
    final gameId = await api.startSolo();

    await expectLater(
      api.submitRanking(gameId, 'ABC'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.message, 'message', '아직 정답을 맞히지 않은 게임이에요'),
      ),
    );
  });

  test('네트워크 오류는 안내 문구로 바꾼다', () async {
    final server = FakeServer()..offline = true;
    await expectLater(
      server.api.startSolo(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', isNull)),
    );
  });

  test('기본 주소에 경로가 있어도 붙여서 요청한다', () async {
    Uri? seen;
    final api = FourSApi(
      baseUrl: Uri.parse('https://example.test/prefix/'),
      client: MockClient((req) async {
        seen = req.url;
        return http.Response(jsonEncode({'entries': []}), 200);
      }),
    );
    await api.rankings(limit: 10);
    expect(seen.toString(), 'https://example.test/prefix/api/rankings?limit=10');
  });
}
