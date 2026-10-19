import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game_logic.dart';

/// 지금까지 던진 추리 한 줄.
class GuessRecord {
  const GuessRecord({required this.guess, required this.result});

  final String guess;
  final GuessResult result;
}

enum SoloStatus { playing, won, lost }

/// 컴퓨터가 정한 숫자를 맞히는 혼자 하기 모드의 상태.
class SoloGame extends ChangeNotifier {
  SoloGame({
    String? secret,
    Random? random,
    DateTime Function()? clock,
    this.maxTries = GameRules.maxTries,
  })  : _random = random,
        _clock = clock ?? DateTime.now {
    _start(secret);
  }

  final Random? _random;
  final DateTime Function() _clock;
  final int maxTries;

  late String _secret;
  late DateTime _startedAt;
  DateTime? _endedAt;
  final List<String> _input = [];
  final List<GuessRecord> _history = [];

  void _start(String? secret) {
    final next = secret ?? NumberBaseball.generateSecret(_random);
    final error = NumberBaseball.validate(next);
    if (error != null) {
      throw ArgumentError.value(next, 'secret', error);
    }
    _secret = next;
    _startedAt = _clock();
    _endedAt = null;
    _input.clear();
    _history.clear();
  }

  String get secret => _secret;

  List<String> get input => List.unmodifiable(_input);

  List<GuessRecord> get history => List.unmodifiable(_history);

  int get tries => _history.length;

  SoloStatus get status {
    if (_history.isNotEmpty && _history.last.result.isWin) {
      return SoloStatus.won;
    }
    if (_history.length >= maxTries) return SoloStatus.lost;
    return SoloStatus.playing;
  }

  bool get isPlaying => status == SoloStatus.playing;

  bool get canSubmit => isPlaying && _input.length == GameRules.digits;

  /// 게임이 끝났으면 끝난 시점까지, 아니면 지금까지 걸린 시간.
  Duration get elapsed => (_endedAt ?? _clock()).difference(_startedAt);

  bool isUsed(String digit) => _input.contains(digit);

  /// 키패드 숫자 입력. 이미 쓴 숫자이거나 칸이 다 찼으면 무시한다.
  void press(String digit) {
    if (!isPlaying) return;
    if (digit.length != 1 || !'0123456789'.contains(digit)) return;
    if (_input.length >= GameRules.digits || _input.contains(digit)) return;
    _input.add(digit);
    notifyListeners();
  }

  void backspace() {
    if (!isPlaying || _input.isEmpty) return;
    _input.removeLast();
    notifyListeners();
  }

  /// 입력한 숫자를 던진다. 던질 수 없으면 `null`.
  GuessResult? submit() {
    if (!canSubmit) return null;
    final guess = _input.join();
    final result = NumberBaseball.judge(_secret, guess);
    _history.add(GuessRecord(guess: guess, result: result));
    _input.clear();
    if (!isPlaying) _endedAt = _clock();
    notifyListeners();
    return result;
  }

  /// 새 비밀 숫자로 다시 시작한다.
  void restart({String? secret}) {
    _start(secret);
    notifyListeners();
  }
}
