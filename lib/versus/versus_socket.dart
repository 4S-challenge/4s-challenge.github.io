import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// 대결방 서버와의 연결 하나. 테스트에서는 가짜로 바꿔 끼운다.
abstract class VersusSocket {
  /// 서버가 보낸 문자열 메시지. 연결이 끊기면 스트림이 끝난다.
  Stream<String> get messages;

  void send(String data);

  Future<void> close();
}

typedef VersusSocketConnector = Future<VersusSocket> Function(Uri uri);

/// web_socket_channel을 쓰는 실제 연결.
class ChannelVersusSocket implements VersusSocket {
  ChannelVersusSocket._(this._channel);

  static Future<VersusSocket> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(const Duration(seconds: 10));
    return ChannelVersusSocket._(channel);
  }

  final WebSocketChannel _channel;

  @override
  Stream<String> get messages =>
      _channel.stream.where((event) => event is String).cast<String>();

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {
      // 이미 닫힘
    }
  }
}
