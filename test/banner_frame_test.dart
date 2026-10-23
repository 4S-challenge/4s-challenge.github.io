import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:four_s_challenge/ads/banner_frame.dart';

void main() {
  testWidgets('하단 배너 자리는 광고 높이만큼만 차지하고 본문을 가리지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(key: Key('body')),
        bottomNavigationBar: BannerFrame(
          size: Size(320, 50),
          child: ColoredBox(key: Key('ad'), color: Colors.white),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(BannerFrame)), const Size(390, 50));
    expect(tester.getSize(find.byKey(const Key('ad'))), const Size(320, 50));
    expect(tester.getSize(find.byKey(const Key('body'))), const Size(390, 844 - 50));
  });
}
