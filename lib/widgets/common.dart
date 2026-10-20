import 'package:flutter/material.dart';

import '../game/game_logic.dart';
import '../theme/app_theme.dart';

/// 화면 폭이 넓은 웹에서도 휴대폰 화면처럼 가운데에 모아준다.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 전광판 숫자 한 칸.
class ScoreboardDigit extends StatelessWidget {
  const ScoreboardDigit({
    super.key,
    required this.text,
    this.width = 58,
    this.height = 72,
    this.fontSize = 38,
    this.active = false,
  });

  final String text;
  final double width;
  final double height;
  final double fontSize;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.board,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.strike : AppColors.line,
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: AppFonts.mono(
          TextStyle(fontSize: fontSize, color: AppColors.strike, height: 1),
        ),
      ),
    );
  }
}

/// S / B / OUT 배지.
class ResultBadges extends StatelessWidget {
  const ResultBadges({super.key, required this.result});

  final GuessResult result;

  @override
  Widget build(BuildContext context) {
    if (result.isOut) {
      return const _Badge(
        text: 'OUT',
        background: AppColors.out,
        foreground: AppColors.onOut,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (result.strikes > 0)
          _Badge(
            text: '${result.strikes}S',
            background: AppColors.strike,
            foreground: AppColors.onStrike,
          ),
        if (result.strikes > 0 && result.balls > 0) const SizedBox(width: 6),
        if (result.balls > 0)
          _Badge(
            text: '${result.balls}B',
            background: AppColors.ball,
            foreground: AppColors.onBall,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum BigButtonStyle { filled, outlined, tonal }

/// 홈·결과 화면의 큰 버튼.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = BigButtonStyle.filled,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BigButtonStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    // 테마의 버튼 글꼴(본문 글꼴)을 이어받고 크기·굵기만 바꾼다.
    final textStyle = (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
      fontSize: height >= 60 ? 18 : 15,
      fontWeight: style == BigButtonStyle.tonal ? FontWeight.w500 : FontWeight.w700,
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final size = Size.fromHeight(height);

    switch (style) {
      case BigButtonStyle.filled:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: size,
            backgroundColor: AppColors.strike,
            foregroundColor: AppColors.onStrike,
            disabledBackgroundColor: AppColors.line,
            disabledForegroundColor: AppColors.muted,
            textStyle: textStyle,
            shape: shape,
          ),
          child: child,
        );
      case BigButtonStyle.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            foregroundColor: AppColors.strike,
            side: const BorderSide(color: AppColors.strike, width: 2),
            textStyle: textStyle,
            shape: shape,
          ),
          child: child,
        );
      case BigButtonStyle.tonal:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: size,
            backgroundColor: AppColors.panel,
            foregroundColor: AppColors.chalk,
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.line),
            ),
          ),
          child: child,
        );
    }
  }
}

/// 게임 규칙 안내 시트.
Future<void> showRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _RulesSheet(),
  );
}

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 15, height: 1.6, color: AppColors.chalk);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '게임 규칙',
              style: AppFonts.display(
                const TextStyle(fontSize: 28, color: AppColors.chalk),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '서로 다른 숫자 4개로 된 비밀 숫자를 맞히는 게임이에요. '
              '0으로 시작할 수 있고, 같은 숫자는 한 번만 쓰여요.',
              style: body,
            ),
            const SizedBox(height: 16),
            const _RuleLine(
              label: 'S',
              color: AppColors.strike,
              onColor: AppColors.onStrike,
              text: '스트라이크 · 숫자와 자리가 모두 맞음',
            ),
            const _RuleLine(
              label: 'B',
              color: AppColors.ball,
              onColor: AppColors.onBall,
              text: '볼 · 숫자는 있지만 자리가 다름',
            ),
            const _RuleLine(
              label: 'OUT',
              color: AppColors.out,
              onColor: AppColors.onOut,
              text: '아웃 · 맞는 숫자가 하나도 없음',
            ),
            const SizedBox(height: 16),
            const Text(
              '4S가 나오면 정답! 횟수 제한 없이, 몇 번 만에 맞히는지가 기록돼요. '
              '정답을 맞히면 이니셜 3글자로 랭킹에 올릴 수 있어요.',
              style: body,
            ),
            const SizedBox(height: 8),
            const Text(
              '예) 비밀 숫자 4725 · 4790 → 2S · 1234 → 2B · 4729 → 3S',
              style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.label,
    required this.color,
    required this.onColor,
    required this.text,
  });

  final String label;
  final Color color;
  final Color onColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Badge(text: label, background: color, foreground: onColor),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: AppColors.chalk),
            ),
          ),
        ],
      ),
    );
  }
}

/// 걸린 시간을 m:ss 로 표시.
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
