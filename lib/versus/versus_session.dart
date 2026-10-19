import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'versus_models.dart';
import 'versus_socket.dart';

enum VersusStatus { connecting, open, reconnecting, closed }

/// 대결방 접속 하나. 서버 상태를 받아 화면에 알리고, 끊기면 다시 연결한다.
class VersusSession extends ChangeNotifier {
  VersusSession({
    required this.code,
    required this.name,
    required Uri Function(String? playerId) socketUri,
    required VersusSocketConnector connector,
    DateTime Function()? clock,
    this.maxReconnectAttempts = 6,
  })  : _socketUri = socketUri,
        _connector = connector,
        _clock = clock ?? DateTime.now;

  final String code;
  final String name;
  final Uri Function(String? playerId) _socketUri;
  final VersusSocketConnector _connector;
  final DateTime Function() _clock;
  final int maxReconnectAttempts;

  final _notices = StreamController<String>.broadcast();

  VersusSocket? _socket;
  StreamSubscription<String>? _sub;
  Timer? _pingTimer;
  Timer? _retryTimer;
  int _attempts = 0;
  bool _disposed = false;
  bool _leaving = false;
  int? _lastTimeoutAt;
  Duration _serverOffset = Duration.zero;

  VersusStatus _status = VersusStatus.connecting;
  String? _playerId;
  VersusSnapshot? _snapshot;
  String? _fatalError;

  VersusStatus get status => _status;

  /// 서버가 정해준 내 ID. 재접속할 때 쓴다.
  String? get playerId => _playerId;

  VersusSnapshot? get snapshot => _snapshot;

  /// 방에 들어갈 수 없거나 연결을 되살리지 못했을 때의 안내. 있으면 끝난 것.
  String? get fatalError => _fatalError;

  /// 잠깐 보여줄 안내(오류, 시간 초과 등).
  Stream<String> get notices => _notices.stream;

  /// 서버 시계 기준 지금 시각(밀리초).
  int get serverNow => _clock().add(_serverOffset).millisecondsSinceEpoch;

  /// 이번 차례에 남은 시간.
  Duration? get remaining {
    final deadline = _snapshot?.turnDeadline;
    if (deadline == null || _snapshot?.phase != VersusPhase.playing) return null;
    final ms = deadline - serverNow;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  Future<void> start() => _connect();

  Future<void> _connect() async {
    if (_disposed || _leaving || _fatalError != null) return;
    final VersusSocket socket;
    try {
      socket = await _connector(_socketUri(_playerId));
    } catch (_) {
      _onDrop();
      return;
    }
    if (_disposed || _leaving) {
      unawaited(socket.close());
      return;
    }
    _socket = socket;
    _sub = socket.messages.listen(
      _handle,
      onDone: _onDrop,
      onError: (Object _) => _onDrop(),
      cancelOnError: true,
    );
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _socket?.send('ping'));
  }

  void _handle(String raw) {
    if (raw == 'pong') return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    switch (decoded['type']) {
      case 'welcome':
        _playerId = decoded['playerId'] as String?;
        _attempts = 0;
        _status = VersusStatus.open;
        notifyListeners();
      case 'state':
        final snap = VersusSnapshot.fromJson(decoded);
        _serverOffset = Duration(
          milliseconds: snap.serverNow - _clock().millisecondsSinceEpoch,
        );
        _announceTimeout(snap);
        _snapshot = snap;
        _status = VersusStatus.open;
        notifyListeners();
      case 'error':
        final message = decoded['message'] as String? ?? '오류가 생겼어요';
        if (decoded['fatal'] == true) {
          _fail(message);
        } else {
          _notices.add(message);
        }
    }
  }

  void _announceTimeout(VersusSnapshot snap) {
    final at = snap.timeoutAt;
    if (at == null || at == _lastTimeoutAt) return;
    final first = _lastTimeoutAt == null && _snapshot == null;
    _lastTimeoutAt = at;
    if (first) return; // 막 들어왔을 때 예전 일은 알리지 않는다.
    _notices.add(
      snap.timeoutSeat == snap.you ? '시간 초과! 상대 차례로 넘어갔어요' : '상대가 시간을 넘겨 내 차례예요',
    );
  }

  void _fail(String message) {
    _fatalError = message;
    _status = VersusStatus.closed;
    _teardownSocket();
    notifyListeners();
  }

  void _teardownSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
  }

  void _onDrop() {
    _teardownSocket();
    if (_disposed || _leaving || _fatalError != null) return;
    _attempts++;
    if (_attempts > maxReconnectAttempts) {
      _fail(_snapshot == null ? '서버에 연결할 수 없어요' : '연결이 끊겼어요');
      return;
    }
    _status = _snapshot == null ? VersusStatus.connecting : VersusStatus.reconnecting;
    notifyListeners();
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _attempts.clamp(1, 5)), _connect);
  }

  void _send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket == null || _status != VersusStatus.open) {
      _notices.add('연결 중이에요. 잠시 후 다시 시도해 주세요');
      return;
    }
    socket.send(jsonEncode(message));
  }

  void setSecret(String secret) => _send({'type': 'setSecret', 'secret': secret});

  void guess(String guess) => _send({'type': 'guess', 'guess': guess});

  void rematch() => _send({'type': 'rematch'});

  /// 방에서 나간다. 대결 중이면 기권패로 처리된다.
  void leave() {
    if (_leaving) return;
    final socket = _socket;
    if (socket != null) socket.send(jsonEncode({'type': 'leave'}));
    _leaving = true;
    _status = VersusStatus.closed;
    _retryTimer?.cancel();
    _teardownSocket();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _teardownSocket();
    _notices.close();
    super.dispose();
  }
}
