import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/game/game_logic.dart';
import 'package:four_s_challenge/game/solo_game.dart';

import 'support/fake_server.dart';

void main() {
  void type(SoloGame game, String digits) {
    for (final d in digits.split('')) {
      game.press(d);
    }
  }

  group('오프라인', () {
    test('서버가 없으면 바로 시작한다', () {
      final game = SoloGame(secret: '4725');
      expect(game.phase, SoloPhase.playing);
      expect(game.isOnline, isFalse);
      expect(game.gameId, isNull);
    });

    test('같은 숫자는 두 번 입력되지 않는다', () {
      final game = SoloGame(secret: '4725');
      type(game, '1123');
      expect(game.input, ['1', '2', '3']);
      expect(game.isUsed('1'), isTrue);
    });

    test('네 칸을 넘게 입력되지 않는다', () {
      final game = SoloGame(secret: '4725');
      type(game, '12345');
      expect(game.input.join(), '1234');
    });

    test('네 칸이 다 차야 던질 수 있다', () async {
      final game = SoloGame(secret: '4725');
      type(game, '123');
      expect(game.canSubmit, isFalse);
      expect(await game.submit(), isNull);
      expect(game.tries, 0);
    });

    test('지우기는 마지막 숫자만 지운다', () {
      final game = SoloGame(secret: '4725');
      type(game, '123');
      game.backspace();
      expect(game.input, ['1', '2']);
    });

    test('던지면 기록이 남고 입력칸이 비워진다', () async {
      final game = SoloGame(secret: '4725');
      type(game, '4729');
      final r = await game.submit();
      expect(r, const GuessResult(strikes: 3, balls: 0));
      expect(game.history.single.guess, '4729');
      expect(game.input, isEmpty);
      expect(game.phase, SoloPhase.playing);
    });

    test('횟수 제한 없이 맞힐 때까지 계속한다', () async {
      final game = SoloGame(secret: '4725');
      for (var i = 0; i < 15; i++) {
        type(game, '1234');
        await game.submit();
      }
      expect(game.tries, 15);
      expect(game.isPlaying, isTrue);

      type(game, '4725');
      await game.submit();
      expect(game.isWon, isTrue);
      expect(game.tries, 16);
      expect(game.answer, '4725');
    });

    test('맞히면 시간이 멈추고 더 이상 입력되지 않는다', () async {
      var now = DateTime(2026, 10, 19, 12);
      final game = SoloGame(secret: '4725', clock: () => now);
      now = now.add(const Duration(seconds: 95));
      type(game, '4725');
      await game.submit();
      expect(game.elapsed, const Duration(seconds: 95));

      now = now.add(const Duration(minutes: 5));
      expect(game.elapsed, const Duration(seconds: 95));
      game.press('1');
      expect(game.input, isEmpty);
    });

    test('규칙에 맞지 않는 비밀 숫자는 거부한다', () {
      expect(() => SoloGame(secret: '1123'), throwsArgumentError);
    });
  });

  group('온라인', () {
    test('서버에서 게임을 시작하고 서버가 판정한다', () async {
      final server = FakeServer(secret: '4725', durationMs: 61000);
      final game = SoloGame(api: server.api);
      expect(game.phase, SoloPhase.starting);
      expect(game.canSubmit, isFalse);

      await game.start();
      expect(game.isOnline, isTrue);
      expect(game.gameId, isNotNull);

      type(game, '4729');
      expect(await game.submit(), const GuessResult(strikes: 3, balls: 0));
      type(game, '4725');
      await game.submit();

      expect(game.isWon, isTrue);
      expect(game.tries, 2);
      expect(game.elapsed, const Duration(seconds: 61));
      expect(server.requests.where((r) => r == 'POST /api/solo/guess').length, 2);
    });

    test('시작할 때 서버에 연결할 수 없으면 오프라인으로 진행한다', () async {
      final server = FakeServer()..offline = true;
      final game = SoloGame(api: server.api);
      await game.start();
      expect(game.phase, SoloPhase.playing);
      expect(game.isOnline, isFalse);
      expect(game.fellBackOffline, isTrue);

      type(game, '1234');
      expect(await game.submit(), isNotNull);
    });

    test('던지는 중에 연결이 끊기면 입력을 유지하고 안내한다', () async {
      final server = FakeServer();
      final game = SoloGame(api: server.api);
      await game.start();
      server.offline = true;

      type(game, '1234');
      expect(await game.submit(), isNull);
      expect(game.error, isNotNull);
      expect(game.input.join(), '1234');
      expect(game.tries, 0);

      server.offline = false;
      expect(await game.submit(), isNotNull);
      expect(game.error, isNull);
      expect(game.tries, 1);
    });
  });
}
