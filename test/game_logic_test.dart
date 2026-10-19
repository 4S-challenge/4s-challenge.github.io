import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/game/game_logic.dart';

void main() {
  group('NumberBaseball.judge', () {
    const secret = '4725';

    test('맞는 숫자가 없으면 OUT', () {
      final r = NumberBaseball.judge(secret, '1368');
      expect(r, const GuessResult(strikes: 0, balls: 0));
      expect(r.isOut, isTrue);
      expect(r.label, 'OUT');
    });

    test('자리가 다른 숫자는 볼', () {
      expect(NumberBaseball.judge(secret, '1234').label, '2B');
    });

    test('자리까지 맞으면 스트라이크', () {
      expect(NumberBaseball.judge(secret, '4790').label, '2S');
    });

    test('스트라이크와 볼이 섞인 경우', () {
      expect(NumberBaseball.judge(secret, '4257').label, '1S 3B');
    });

    test('3S가 나올 수 있다', () {
      final r = NumberBaseball.judge(secret, '4729');
      expect(r.label, '3S');
      expect(r.isWin, isFalse);
    });

    test('4S면 정답', () {
      final r = NumberBaseball.judge(secret, '4725');
      expect(r.label, '4S');
      expect(r.isWin, isTrue);
    });

    test('0으로 시작하는 숫자도 판정한다', () {
      expect(NumberBaseball.judge('0123', '1023').label, '2S 2B');
    });

    test('규칙에 맞지 않는 추리는 예외', () {
      expect(() => NumberBaseball.judge(secret, '123'), throwsArgumentError);
      expect(() => NumberBaseball.judge(secret, '1123'), throwsArgumentError);
      expect(() => NumberBaseball.judge('1123', '1234'), throwsArgumentError);
    });
  });

  group('NumberBaseball.validate', () {
    test('올바른 입력', () {
      expect(NumberBaseball.validate('0123'), isNull);
      expect(NumberBaseball.validate('9876'), isNull);
    });

    test('자릿수가 다르면 오류', () {
      expect(NumberBaseball.validate('123'), isNotNull);
      expect(NumberBaseball.validate('12345'), isNotNull);
    });

    test('숫자가 아니면 오류', () {
      expect(NumberBaseball.validate('12a4'), isNotNull);
    });

    test('중복 숫자는 오류', () {
      expect(NumberBaseball.validate('1213'), isNotNull);
    });
  });

  group('NumberBaseball.generateSecret', () {
    test('항상 규칙에 맞는 비밀 숫자를 만든다', () {
      final rng = Random(42);
      for (var i = 0; i < 500; i++) {
        final secret = NumberBaseball.generateSecret(rng);
        expect(NumberBaseball.validate(secret), isNull, reason: secret);
      }
    });

    test('같은 시드면 같은 숫자', () {
      expect(
        NumberBaseball.generateSecret(Random(7)),
        NumberBaseball.generateSecret(Random(7)),
      );
    });
  });
}
