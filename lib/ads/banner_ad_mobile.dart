import 'dart:io' show Platform;

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

String get _bannerUnitId {
  if (Platform.isIOS) return _bannerIos.isNotEmpty ? _bannerIos : _testBannerIos;
  return _bannerAndroid.isNotEmpty ? _bannerAndroid : _testBannerAndroid;
}

bool _initialized = false;

/// 앱 시작 때 한 번 부른다.
Future<void> initAds() async {
  if (!_adsSupported || _initialized) return;
  _initialized = true;
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('광고 초기화 실패: $e');
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
