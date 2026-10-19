import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // 웹 초대 링크: https://4s-challenge.github.io/?room=K7Q2
  final room = Uri.base.queryParameters['room'];
  runApp(FourSApp(initialRoomCode: room?.toUpperCase()));
}
