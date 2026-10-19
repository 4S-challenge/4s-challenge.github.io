import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/four_s_api.dart';
import 'game_logic.dart';

/// 지금까지 던진 추리 한 줄.
class GuessRecord {
  const GuessRecord({required this.guess, required this.result});

  final String guess;
  final GuessResult result;
}

enum SoloPhase { starting, playing, won }

/// 혼자 하기 한 판. 시도 횟수 제한 없이 맞힐 때까지 계속한다.
///
/// 서버([FourSApi])가 있으면 서버가 비밀 숫자를 갖고 판정한다. 그래야 랭킹에
/// 올릴 수 있다. 서버가 없거나 연결에 실패하면 기기 안에서 판정한다(오프라인).
class SoloGame extends ChangeNotifier {
  SoloGame({
    FourSApi? api,
    String? secret,
    Random? random,
    DateTime Function()? clock,
  })  : _api = api,
        _random = random,
        _clock = clock ?? DateTime.now {
    if (api == null) {
      _startLocal(secret);
    } else {
      _phase = SoloPhase.starting;
    }
  }

  final FourSApi? _api;
  final Random? _random;
  final DateTime Function() _clock;

  SoloPhase _phase = SoloPhase.playing;
  String? _secret; // 오프라인일 때만 알고 있다.
  String? _gameId; // 온라인일 때 서버 게임 ID.
  bool _fellBackOffline = false;
  bool _busy = false;
  String? _error;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _endedAt;
  Duration? _serverDuration;
  final List<String> _input = [];
  final List<GuessRecord> _history = [];

  void _startLocal(String? secret) {
    final next = secret ?? NumberBaseball.generateSecret(_random);
    final error = NumberBaseball.validate(next);
    if (error != null) {
      throw ArgumentError.value(next, 'secret', error);
    }
    _secret = next;
    _phase = SoloPhase.playing;
    _startedAt = _clock();
  }

  /// 서버 게임을 시작한다. 실패하면 오프라인으로 바꿔 바로 시작한다.
  Future<void> start() async {
    final api = _api;
    if (api == null || _phase != SoloPhase.starting) return;
    try {
      _gameId = await api.startSolo();
      _phase = SoloPhase.playing;
      _startedAt = _clock();
    } on ApiException {
      _fellBackOffline = true;
      _startLocal(null);
    }
    notifyListeners();
  }

  SoloPhase get phase => _phase;

  bool get isPlaying => _phase == SoloPhase.playing;

  bool get isWon => _phase == SoloPhase.won;

  /// 서버에서 판정하는 게임인지. 랭킹 등록은 이때만 가능하다.
  bool get isOnline => _gameId != null;

  String? get gameId => _gameId;

  /// 서버 연결에 실패해서 오프라인으로 바뀌었는지.
  bool get fellBackOffline => _fellBackOffline;

  /// 서버 판정을 기다리는 중.
  bool get busy => _busy;

  /// 마지막 던지기가 실패했을 때의 안내 문구.
  String? get error => _error;

  List<String> get input => List.unmodifiable(_input);

  List<GuessRecord> get history => List.unmodifiable(_history);

  int get tries => _history.length;

  bool get canSubmit =>
      isPlaying && !_busy && _input.length == GameRules.digits;

  /// 맞혔으면 정답(마지막 추리).
  String? get answer => isWon ? _history.last.guess : null;

  /// 걸린 시간. 온라인으로 맞혔으면 서버가 잰 값, 아니면 기기 시계 기준.
  Duration get elapsed =>
      _serverDuration ?? (_endedAt ?? _clock()).difference(_startedAt);

  bool isUsed(String digit) => _input.contains(digit);

  /// 키패드 숫자 입력. 이미 쓴 숫자이거나 칸이 다 찼으면 무시한다.
  void press(String digit) {
    if (!isPlaying || _busy) return;
    if (digit.length != 1 || !'0123456789'.contains(digit)) return;
    if (_input.length >= GameRules.digits || _input.contains(digit)) return;
    _input.add(digit);
    _error = null;
    notifyListeners();
  }

  void backspace() {
    if (!isPlaying || _busy || _input.isEmpty) return;
    _input.removeLast();
    _error = null;
    notifyListeners();
  }

  /// 입력한 숫자를 던진다. 던질 수 없거나 서버 요청이 실패하면 `null`.
  Future<GuessResult?> submit() async {
    if (!canSubmit) return null;
    final guess = _input.join();
    final gameId = _gameId;
    final api = _api;

    GuessResult result;
    if (gameId != null && api != null) {
      _busy = true;
      _error = null;
      notifyListeners();
      try {
        final remote = await api.guess(gameId, guess);
        result = remote.result;
        _serverDuration = remote.duration;
      } on ApiException catch (e) {
        _busy = false;
        _error = e.message;
        notifyListeners();
        return null;
      }
      _busy = false;
    } else {
      result = NumberBaseball.judge(_secret!, guess);
    }

    _history.add(GuessRecord(guess: guess, result: result));
    _input.clear();
    if (result.isWin) {
      _phase = SoloPhase.won;
      _endedAt = _clock();
    }
    notifyListeners();
    return result;
  }
}
