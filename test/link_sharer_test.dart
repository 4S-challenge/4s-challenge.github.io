import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/share/link_sharer.dart';

void main() {
  test('복사 문구는 글 다음 줄에 링크', () {
    expect(shareCopyText('대결해요!', 'https://a.test/?room=K7Q2'), '대결해요!\nhttps://a.test/?room=K7Q2');
    expect(shareCopyText('대결해요!', null), '대결해요!');
    expect(shareCopyText('대결 https://a.test', 'https://a.test'), '대결 https://a.test');
  });

  test('앱 안 브라우저는 공유 창 대신 복사', () {
    const inApp = [
      // 카카오톡 (Android / iPhone)
      'Mozilla/5.0 (Linux; Android 14; SM-S918N Build/UP1A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/129.0 Mobile Safari/537.36 KAKAOTALK 10.8.5',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 KAKAOTALK 10.8.5',
      // 네이버 앱
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 NAVER(inapp; search; 2000; 12.8.0)',
      // 인스타그램
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 340.0',
      // 라인
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari Line/14.10.0',
    ];
    for (final ua in inApp) {
      expect(isInAppBrowser(ua), isTrue, reason: ua);
    }
  });

  test('일반 휴대폰 브라우저는 공유 창 사용', () {
    const browsers = [
      // 크롬 (Android)
      'Mozilla/5.0 (Linux; Android 14; SM-S918N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36',
      // 사파리 (iPhone)
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
      // 삼성 인터넷
      'Mozilla/5.0 (Linux; Android 14; SM-S918N) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/26.0 Chrome/122.0.0.0 Mobile Safari/537.36',
      // iPhone 크롬
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/129.0 Mobile/15E148 Safari/604.1',
    ];
    for (final ua in browsers) {
      expect(isInAppBrowser(ua), isFalse, reason: ua);
    }
  });
}
