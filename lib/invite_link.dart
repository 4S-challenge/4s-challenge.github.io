/// 친구와 대결 초대 링크: https://4s-challenge.ohsangplay.com/?room=K7Q2
///
/// 웹에서는 페이지 주소로, 앱에서는 App Links(Android)·Universal Links(iOS)로 들어온다.
library;

final _roomCodePattern = RegExp(r'^[A-Z0-9]{4}$');

/// 초대 링크에서 방 코드를 꺼낸다. 방 코드가 없거나 형식이 틀리면 `null`.
String? roomCodeFromUri(Uri uri) {
  final code = uri.queryParameters['room']?.trim().toUpperCase();
  if (code == null || !_roomCodePattern.hasMatch(code)) return null;
  return code;
}
