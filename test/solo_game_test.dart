import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/game/game_logic.dart';
import 'package:four_s_challenge/game/solo_game.dart';

void main() {
  void type(SoloGame game, String digits) {
    for (final d in digits.split('')) {
      game.press(d);
    }
  }

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

  test('네 칸이 다 차야 던질 수 있다', () {
    final game = SoloGame(secret: '4725');
    type(game, '123');
    expect(game.canSubmit, isFalse);
    expect(game.submit(), isNull);
    expect(game.tries, 0);
  });

  test('지우기는 마지막 숫자만 지운다', () {
    final game = SoloGame(secret: '4725');
    type(game, '123');
    game.backspace();
    expect(game.input, ['1', '2']);
  });

  test('던지면 기록이 남고 입력칸이 비워진다', () {
    final game = SoloGame(secret: '4725');
    type(game, '4729');
    final r = game.submit();
    expect(r, const GuessResult(strikes: 3, balls: 0));
    expect(game.history.single.guess, '4729');
    expect(game.input, isEmpty);
    expect(game.status, SoloStatus.playing);
  });

  test('4S면 승리하고 더 이상 입력되지 않는다', () {
    var now = DateTime(2026, 10, 19, 12);
    final game = SoloGame(secret: '4725', clock: () => now);
    now = now.add(const Duration(seconds: 95));
    type(game, '4725');
    game.submit();
    expect(game.status, SoloStatus.won);
    expect(game.elapsed, const Duration(seconds: 95));

    now = now.add(const Duration(minutes: 5));
    expect(game.elapsed, const Duration(seconds: 95));
    game.press('1');
    expect(game.input, isEmpty);
  });

  test('최대 시도 안에 못 맞히면 실패', () {
    final game = SoloGame(secret: '4725', maxTries: 2);
    type(game, '1234');
    game.submit();
    type(game, '5678');
    game.submit();
    expect(game.status, SoloStatus.lost);
    expect(game.isPlaying, isFalse);
  });

  test('다시 시작하면 기록이 초기화된다', () {
    final game = SoloGame(secret: '4725');
    type(game, '1234');
    game.submit();
    game.restart(secret: '0987');
    expect(game.history, isEmpty);
    expect(game.secret, '0987');
    expect(game.status, SoloStatus.playing);
  });

  test('규칙에 맞지 않는 비밀 숫자는 거부한다', () {
    expect(() => SoloGame(secret: '1123'), throwsArgumentError);
  });
}
