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
    this.connected = true,
    this.left = false,
    this.ready = false,
  });

  factory VersusMe.fromJson(Map<String, dynamic> json) => VersusMe(
        name: json['name'] as String? ?? '',
        secret: json['secret'] as String?,
        guesses: _guessesFrom(json['guesses']),
        rematch: json['rematch'] as bool? ?? false,
        connected: json['connected'] as bool? ?? true,
        left: json['left'] as bool? ?? false,
        ready: json['ready'] as bool? ?? json['secret'] != null,
      );

  /// 관전 화면에서 첫 번째 선수의 상태를 보여줄 때 쓴다.
  final bool connected;
  final bool left;
  final bool ready;

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

/// 관전자 한 명.
class VersusSpectator {
  const VersusSpectator({required this.name, required this.since, this.me = false});

  factory VersusSpectator.fromJson(Map<String, dynamic> json) => VersusSpectator(
        name: json['name'] as String? ?? '',
        since: json['since'] as int? ?? 0,
        me: json['me'] as bool? ?? false,
      );

  final String name;

  /// 관전을 시작한 시각(서버 시계, 밀리초).
  final int since;

  /// 이 기기(나)인지.
  final bool me;

  /// 같은 사람인지 구분하는 값.
  String get key => '$name@$since';
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
    this.spectating = false,
    this.spectators = const [],
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
      spectating: json['role'] == 'spectator',
      spectators: [
        if (json['spectators'] is List)
          for (final item in (json['spectators'] as List).whereType<Map<String, dynamic>>())
            VersusSpectator.fromJson(item),
      ],
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

  /// 관전자로 보고 있는지. 이때 [me]는 첫 번째 선수, [opponent]는 두 번째 선수다.
  final bool spectating;

  /// 지금 관전 중인 사람들.
  final List<VersusSpectator> spectators;

  bool get myTurn => !spectating && phase == VersusPhase.playing && turn == you;

  /// 관전 화면에서: [me] 쪽(첫 번째 선수) 차례인지.
  bool get firstPlayerTurn => phase == VersusPhase.playing && turn == you;

  bool get iWon => !spectating && phase == VersusPhase.finished && winner == you;

  /// 이긴 사람 이름 (끝났을 때).
  String? get winnerName {
    if (phase != VersusPhase.finished || winner == null) return null;
    return winner == you ? me.name : opponent?.name;
  }

  bool get byForfeit => endReason == 'forfeit';
}
