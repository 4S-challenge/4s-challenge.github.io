import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 야구장 전광판 팔레트.
class AppColors {
  AppColors._();

  static const ground = Color(0xFF0E2A22);
  static const board = Color(0xFF08201A);
  static const panel = Color(0xFF163B30);
  static const panelHigh = Color(0xFF1F4A3D);
  static const line = Color(0xFF2C5A4B);

  static const chalk = Color(0xFFF4F1E8);
  static const muted = Color(0xFFA9BDB4);
  static const disabled = Color(0xFF4F6E63);

  static const strike = Color(0xFFF5B83D);
  static const onStrike = Color(0xFF1A1405);
  static const ball = Color(0xFF8FD3F4);
  static const onBall = Color(0xFF0A2633);
  static const out = Color(0xFFE8836B);
  static const onOut = Color(0xFF2A0E08);
}

/// 글꼴. 테스트에서는 네트워크 글꼴을 끄기 위해 [useGoogleFonts]를 false로 둔다.
class AppFonts {
  AppFonts._();

  static bool useGoogleFonts = true;

  /// [useGoogleFonts]가 false일 때 쓸 글꼴 이름. 스토어 스크린샷처럼 글꼴 파일을
  /// 직접 불러온 경우에만 정한다. null이면 기본 글꼴(테스트용)을 쓴다.
  static String? localDisplayFamily;
  static String? localMonoFamily;
  static String? localBodyFamily;

  /// 제목용 굵은 한글 글꼴.
  static TextStyle display(TextStyle style) => useGoogleFonts
      ? GoogleFonts.blackHanSans(textStyle: style)
      : style.copyWith(fontFamily: localDisplayFamily);

  /// 전광판 숫자용 고정폭 글꼴.
  static TextStyle mono(TextStyle style) => useGoogleFonts
      ? GoogleFonts.spaceMono(textStyle: style.copyWith(fontWeight: FontWeight.w700))
      : style.copyWith(fontFamily: localMonoFamily ?? 'monospace', fontWeight: FontWeight.w700);

  static TextTheme body(TextTheme base) => useGoogleFonts
      ? GoogleFonts.ibmPlexSansKrTextTheme(base)
      : base.apply(fontFamily: localBodyFamily);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.ground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.strike,
      onPrimary: AppColors.onStrike,
      secondary: AppColors.ball,
      onSecondary: AppColors.onBall,
      error: AppColors.out,
      onError: AppColors.onOut,
      surface: AppColors.panel,
      onSurface: AppColors.chalk,
    ),
  );

  final textTheme = AppFonts.body(base.textTheme).apply(
    bodyColor: AppColors.chalk,
    displayColor: AppColors.chalk,
  );

  return base.copyWith(
    textTheme: textTheme,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.chalk,
      contentTextStyle: TextStyle(color: AppColors.ground, fontSize: 15),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      showDragHandle: true,
    ),
  );
}
