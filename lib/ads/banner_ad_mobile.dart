import 'dart:io' show Platform;

import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'banner_frame.dart';

/// Google 테스트 광고 단위 ID. 실제 ID는 config/prod.json에 넣는다.
const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

const _bannerAndroid = String.fromEnvironment('ADMOB_ANDROID_BANNER_ID');
const _bannerIos = String.fromEnvironment('ADMOB_IOS_BANNER_ID');

/// 광고를 띄울 수 있는 환경인지. 테스트(flutter test)와 Android/iOS 외 플랫폼은 끈다.
bool get _adsSupported {
  if (kIsWeb) return false;
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// 디버그 빌드(flutter run)는 항상 테스트 광고를 쓴다. 개발 중 실제 광고를 눌러 계정이 제한되는 것을 막는다.
String get _bannerUnitId {
  if (kDebugMode) return Platform.isIOS ? _testBannerIos : _testBannerAndroid;
  if (Platform.isIOS) return _bannerIos.isNotEmpty ? _bannerIos : _testBannerIos;
  return _bannerAndroid.isNotEmpty ? _bannerAndroid : _testBannerAndroid;
}

bool _initialized = false;

/// 광고 SDK 준비가 끝나면 완료된다. 배너는 이걸 기다렸다가 광고를 요청한다.
final _ready = Completer<void>();

/// 앱 시작 때 한 번 부른다.
/// iOS는 첫 화면이 뜬 뒤 앱 추적 투명성(ATT) 창으로 먼저 묻고, 답을 받은 뒤 광고 SDK를 준비한다.
Future<void> initAds() async {
  if (!_adsSupported || _initialized) return;
  _initialized = true;
  if (Platform.isIOS) await _askTracking();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('광고 초기화 실패: $e');
  }
  if (!_ready.isCompleted) _ready.complete();
}

Future<void> _askTracking() async {
  try {
    // 앱이 화면에 완전히 뜬 상태에서 물어야 iOS가 창을 보여준다.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('추적 허용 확인 실패: $e');
  }
}

/// 화면 맨 아래 배너. 광고를 받아오면 표준 배너(320×50) 높이만큼 자리를 차지하고,
/// 받지 못하면 아무 자리도 차지하지 않는다.
class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!_adsSupported) return;
    unawaited(_ready.future.then((_) {
      if (mounted) _load();
    }));
  }

  void _load() {
    _ad = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고를 받지 못함: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return BannerFrame(
      size: Size(ad.size.width.toDouble(), ad.size.height.toDouble()),
      child: AdWidget(ad: ad),
    );
  }
}
