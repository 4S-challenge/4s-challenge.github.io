import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 화면 맨 아래 배너 광고 자리. 가로는 화면 폭만큼 바탕색을 칠하고,
/// 세로는 광고 높이(+ 시스템 내비게이션 영역)만큼만 차지한다.
///
/// Scaffold.bottomNavigationBar는 높이 제한이 화면 전체라서, 크기를 정하지 않은
/// Container(alignment: ...)를 쓰면 화면 전체를 덮어 본문이 사라진다. 그래서 heightFactor: 1로
/// 높이를 광고에 맞춘다.
class BannerFrame extends StatelessWidget {
  const BannerFrame({super.key, required this.size, required this.child});

  /// 광고 크기 (표준 배너 320×50).
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.board,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );
  }
}
