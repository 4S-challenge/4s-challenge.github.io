import '../game/game_logic.dart';
import '../game/solo_game.dart';

/// 대결방 진행 단계. 서버의 phase와 같다.
enum VersusPhase { waiting, setting, playing, finished }

VersusPhase _phaseFrom(Object? value) => switch (value) {
      'setting' => VersusPhase.setting,
      'playing' => VersusPhase.playing,
      'finished' => VersusPhase.finished,
      _ => VersusPhase.waiting,
    };

List<GuessRecord> _guessesFrom(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value.cast<Map<String, dynamic>>())
      GuessRecord(
        guess: item['guess'] as String,
        result: GuessResult(
          strikes: item['strikes'] as int,
          balls: item['balls'] as int,
        ),
      ),
  ];
}

class VersusMe {
  const VersusMe({
    required this.name,
    required this.secret,
    required this.guesses,
    required this.rematch,
  });

  factory VersusMe.fromJson(Map<String, dynamic> json) => VersusMe(
        name: json['name'] as String? ?? '',
        secret: json['secret'] as String?,
        guesses: _guessesFrom(json['guesses']),
        rematch: json['rematch'] as bool? ?? false,
      );

  final String name;

  /// 상대가 맞혀야 하는 내 비밀 숫자. 아직 안 정했으면 null.
  final String? secret;

  /// 내가 상대 숫자에 던진 기록.
  final List<GuessRecord> guesses;
  final bool rematch;
}

class VersusOpponent {
  const VersusOpponent({
    required this.name,
    required this.connected,
    required this.left,
    required this.ready,
    required this.rematch,
    required this.guesses,
    required this.secret,
  });

  factory VersusOpponent.fromJson(Map<String, dynamic> json) => VersusOpponent(
        name: json['name'] as String? ?? '',
        connected: json['connected'] as bool? ?? false,
        left: json['left'] as bool? ?? false,
        ready: json['ready'] as bool? ?? false,
        rematch: json['rematch'] as bool? ?? false,
        guesses: _guessesFrom(json['guesses']),
        secret: json['secret'] as String?,
      );

  final String name;
  final bool connected;
  final bool left;

  /// 비밀 숫자를 정했는지.
  final bool ready;
  final bool rematch;

  /// 상대가 내 숫자에 던진 기록.
  final List<GuessRecord> guesses;

  /// 대결이 끝난 뒤에만 공개된다.
  final String? secret;
}

/// 서버가 보내준 방 상태 한 장.
class VersusSnapshot {
  const VersusSnapshot({
    required this.code,
    required this.phase,
    required this.round,
    required this.serverNow,
    required this.you,
    required this.turn,
    required this.turnDeadline,
    required this.winner,
    required this.endReason,
    required this.timeoutSeat,
    required this.timeoutAt,
    required this.me,
    required this.opponent,
  });

  factory VersusSnapshot.fromJson(Map<String, dynamic> json) {
    final event = json['lastEvent'];
    final isTimeout = event is Map && event['type'] == 'timeout';
    final me = json['me'];
    final opp = json['opponent'];
    return VersusSnapshot(
      code: json['code'] as String? ?? '',
      phase: _phaseFrom(json['phase']),
      round: json['round'] as int? ?? 1,
      serverNow: json['serverNow'] as int? ?? 0,
      you: json['you'] as int? ?? 0,
      turn: json['turn'] as int?,
      turnDeadline: json['turnDeadline'] as int?,
      winner: json['winner'] as int?,
      endReason: json['endReason'] as String?,
      timeoutSeat: isTimeout ? event['seat'] as int? : null,
      timeoutAt: isTimeout ? event['at'] as int? : null,
      me: me is Map<String, dynamic>
          ? VersusMe.fromJson(me)
          : const VersusMe(name: '', secret: null, guesses: [], rematch: false),
      opponent: opp is Map<String, dynamic> ? VersusOpponent.fromJson(opp) : null,
    );
  }

  final String code;
  final VersusPhase phase;
  final int round;
  final int serverNow;
  final int you;
  final int? turn;
  final int? turnDeadline;
  final int? winner;
  final String? endReason;
  final int? timeoutSeat;
  final int? timeoutAt;
  final VersusMe me;
  final VersusOpponent? opponent;

  bool get myTurn => phase == VersusPhase.playing && turn == you;

  bool get iWon => phase == VersusPhase.finished && winner == you;

  bool get byForfeit => endReason == 'forfeit';
}
