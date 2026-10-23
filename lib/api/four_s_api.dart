import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../game/game_logic.dart';
import '../versus/versus_socket.dart';

/// 서버 요청 실패. [message]는 사용자에게 그대로 보여줘도 되는 문장이다.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// 서버가 판정한 추리 결과.
class RemoteGuess {
  const RemoteGuess({
    required this.result,
    required this.tries,
    required this.solved,
    this.duration,
  });

  final GuessResult result;
  final int tries;
  final bool solved;

  /// 맞혔을 때 서버가 잰 걸린 시간.
  final Duration? duration;
}

/// 랭킹 한 줄.
class RankingEntry {
  const RankingEntry({
    required this.id,
    required this.rank,
    required this.initials,
    required this.tries,
    required this.duration,
    required this.createdAt,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        id: json['id'] as int,
        rank: json['rank'] as int,
        initials: json['initials'] as String,
        tries: json['tries'] as int,
        duration: Duration(milliseconds: json['durationMs'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );

  final int id;
  final int rank;
  final String initials;
  final int tries;
  final Duration duration;
  final DateTime createdAt;
}

/// Cloudflare Worker 랭킹 서버 클라이언트.
class FourSApi {
  FourSApi({
    required this.baseUrl,
    http.Client? client,
    VersusSocketConnector? socketConnector,
  })  : _client = client ?? http.Client(),
        socketConnector = socketConnector ?? ChannelVersusSocket.connect;

  /// 빌드할 때 `--dart-define=API_BASE_URL=...`로 넘긴 주소. 없으면 `null`(오프라인).
  static FourSApi? fromEnvironment() {
    const url = String.fromEnvironment('API_BASE_URL');
    if (url.isEmpty) return null;
    return FourSApi(baseUrl: Uri.parse(url));
  }

  static const _timeout = Duration(seconds: 8);

  final Uri baseUrl;
  final http.Client _client;

  /// 대결방 WebSocket을 여는 방법. 테스트에서 바꿔 끼운다.
  final VersusSocketConnector socketConnector;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path', queryParameters: query);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final http.Response res;
    try {
      final request = http.Request(method, _uri(path, query));
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(_timeout);
      res = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('서버 응답이 늦어요. 잠시 후 다시 시도해 주세요');
    } catch (_) {
      throw const ApiException('서버에 연결할 수 없어요');
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      data = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && data != null) {
      return data;
    }
    final message = data?['error'];
    throw ApiException(
      message is String ? message : '잠시 후 다시 시도해 주세요',
      status: res.statusCode,
    );
  }

  /// 새 게임을 시작하고 게임 ID를 돌려준다.
  Future<String> startSolo() async {
    final data = await _send('POST', '/api/solo/start');
    return data['gameId'] as String;
  }

  Future<RemoteGuess> guess(String gameId, String guess) async {
    final data = await _send(
      'POST',
      '/api/solo/guess',
      body: {'gameId': gameId, 'guess': guess},
    );
    final durationMs = data['durationMs'];
    return RemoteGuess(
      result: GuessResult(
        strikes: data['strikes'] as int,
        balls: data['balls'] as int,
      ),
      tries: data['tries'] as int,
      solved: data['solved'] as bool,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
    );
  }

  Future<RankingEntry> submitRanking(String gameId, String initials) async {
    final data = await _send(
      'POST',
      '/api/rankings',
      body: {'gameId': gameId, 'initials': initials},
    );
    return RankingEntry.fromJson(data['entry'] as Map<String, dynamic>);
  }

  /// 새 대결방을 만들고 방 코드를 돌려준다.
  Future<String> createRoom() async {
    final data = await _send('POST', '/api/versus/rooms');
    return data['code'] as String;
  }

  /// 들어가기 전에 방 요약을 본다 (대결 중인지, 누가 하는지, 관전자 수).
  Future<RoomPeek> peekRoom(String code) async {
    final data = await _send('GET', '/api/versus/rooms/$code');
    return RoomPeek.fromJson(data);
  }

  /// 대결방 WebSocket 주소. [watch]면 꽉 찬 방에 관전자로 들어간다.
  Uri roomSocketUri(String code, {required String name, String? playerId, bool watch = false}) {
    final uri = _uri('/api/versus/rooms/$code/ws', {
      'name': name,
      if (playerId != null) 'playerId': playerId,
      if (watch) 'watch': '1',
    });
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');
  }

  Future<List<RankingEntry>> rankings({int limit = 50}) async {
    final data = await _send(
      'GET',
      '/api/rankings',
      query: {'limit': '$limit'},
    );
    return (data['entries'] as List)
        .cast<Map<String, dynamic>>()
        .map(RankingEntry.fromJson)
        .toList();
  }
}

/// 위젯 트리 어디서든 서버 클라이언트를 꺼내 쓰게 해준다. 서버가 없으면 `api`는 `null`.
class ApiScope extends InheritedWidget {
  const ApiScope({super.key, required this.api, required super.child});

  final FourSApi? api;

  static FourSApi? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ApiScope>()?.api;

  @override
  bool updateShouldNotify(ApiScope oldWidget) => oldWidget.api != api;
}

/// 들어가기 전에 보는 대결방 요약.
class RoomPeek {
  const RoomPeek({required this.full, required this.players, required this.spectators});

  factory RoomPeek.fromJson(Map<String, dynamic> json) => RoomPeek(
        full: json['full'] as bool? ?? false,
        players: [
          if (json['players'] is List)
            for (final name in (json['players'] as List).whereType<String>()) name,
        ],
        spectators: json['spectators'] as int? ?? 0,
      );

  /// 두 자리가 다 차서 관전으로만 들어갈 수 있는지.
  final bool full;

  /// 대결 중인 두 사람 이니셜.
  final List<String> players;

  /// 지금 관전 중인 사람 수.
  final int spectators;
}
