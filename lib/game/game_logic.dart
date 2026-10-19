import 'dart:math';

/// 게임 공통 규칙.
class GameRules {
  GameRules._();

  /// 비밀 숫자 자릿수.
  static const int digits = 4;

  /// 혼자 하기 최대 시도 횟수.
  static const int maxTries = 10;
}

/// 한 번의 추리에 대한 판정 결과.
class GuessResult {
  const GuessResult({required this.strikes, required this.balls});

  final int strikes;
  final int balls;

  bool get isOut => strikes == 0 && balls == 0;

  bool get isWin => strikes == GameRules.digits;

  /// 예: `OUT`, `2S`, `1S 2B`, `3B`.
  String get label {
    if (isOut) return 'OUT';
    final parts = <String>[
      if (strikes > 0) '${strikes}S',
      if (balls > 0) '${balls}B',
    ];
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is GuessResult && other.strikes == strikes && other.balls == balls;

  @override
  int get hashCode => Object.hash(strikes, balls);

  @override
  String toString() => 'GuessResult($label)';
}

/// 숫자야구 판정 로직. 상태가 없는 순수 함수 모음.
class NumberBaseball {
  NumberBaseball._();

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// 서로 다른 숫자로 이루어진 [GameRules.digits]자리 비밀 숫자를 만든다.
  /// 0으로 시작해도 된다.
  static String generateSecret([Random? random]) {
    final rng = random ?? Random.secure();
    final pool = List<String>.generate(10, (i) => '$i');
    final buffer = StringBuffer();
    for (var i = 0; i < GameRules.digits; i++) {
      buffer.write(pool.removeAt(rng.nextInt(pool.length)));
    }
    return buffer.toString();
  }

  /// 추리(또는 비밀 숫자)가 규칙에 맞는지 확인한다.
  /// 맞으면 `null`, 틀리면 사용자에게 보여줄 메시지를 돌려준다.
  static String? validate(String value) {
    if (value.length != GameRules.digits) {
      return '숫자 ${GameRules.digits}개를 입력해 주세요';
    }
    if (!_digitsOnly.hasMatch(value)) {
      return '숫자만 입력할 수 있어요';
    }
    if (value.split('').toSet().length != value.length) {
      return '같은 숫자는 한 번만 쓸 수 있어요';
    }
    return null;
  }

  /// [secret]에 대해 [guess]를 판정한다.
  static GuessResult judge(String secret, String guess) {
    final secretError = validate(secret);
    if (secretError != null) {
      throw ArgumentError.value(secret, 'secret', secretError);
    }
    final guessError = validate(guess);
    if (guessError != null) {
      throw ArgumentError.value(guess, 'guess', guessError);
    }

    var strikes = 0;
    var balls = 0;
    for (var i = 0; i < guess.length; i++) {
      if (guess[i] == secret[i]) {
        strikes++;
      } else if (secret.contains(guess[i])) {
        balls++;
      }
    }
    return GuessResult(strikes: strikes, balls: balls);
  }
}
