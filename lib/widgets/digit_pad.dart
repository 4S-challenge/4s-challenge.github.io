import 'package:flutter/material.dart';

import '../game/game_logic.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// 네 자리 숫자 입력 상태. 같은 숫자는 한 번만 들어간다.
class DigitEntry extends ChangeNotifier {
  final List<String> _digits = [];

  List<String> get digits => List.unmodifiable(_digits);

  String get value => _digits.join();

  bool get isComplete => _digits.length == GameRules.digits;

  bool isUsed(String digit) => _digits.contains(digit);

  void press(String digit) {
    if (digit.length != 1 || !'0123456789'.contains(digit)) return;
    if (_digits.length >= GameRules.digits || _digits.contains(digit)) return;
    _digits.add(digit);
    notifyListeners();
  }

  void backspace() {
    if (_digits.isEmpty) return;
    _digits.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_digits.isEmpty) return;
    _digits.clear();
    notifyListeners();
  }
}

/// 입력한 숫자 네 칸.
class DigitSlots extends StatelessWidget {
  const DigitSlots({
    super.key,
    required this.digits,
    this.size = 60,
    this.showCursor = true,
  });

  final List<String> digits;
  final double size;
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '입력한 숫자 ${digits.isEmpty ? '없음' : digits.join(' ')}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < GameRules.digits; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            ScoreboardDigit(
              text: i < digits.length ? digits[i] : '',
              width: size,
              height: size * 7 / 6,
              fontSize: size * 0.56,
              active: showCursor && i == digits.length,
            ),
          ],
        ],
      ),
    );
  }
}

/// 숫자 키패드 + 지우기 + 확인 버튼.
class DigitPad extends StatelessWidget {
  const DigitPad({
    super.key,
    required this.entry,
    required this.onSubmit,
    required this.submitLabel,
    this.enabled = true,
    this.keyHeight = 52,
  });

  final DigitEntry entry;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool enabled;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    Widget row(List<String> digits) => Row(
          children: [
            for (var i = 0; i < digits.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Key(
                  key: Key('vkey-${digits[i]}'),
                  height: keyHeight,
                  onPressed: enabled && !entry.isUsed(digits[i])
                      ? () => entry.press(digits[i])
                      : null,
                  child: Text(
                    digits[i],
                    style: AppFonts.mono(const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ],
          ],
        );

    return Column(
      children: [
        row(const ['1', '2', '3', '4', '5']),
        const SizedBox(height: 8),
        row(const ['6', '7', '8', '9', '0']),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Key(
                key: const Key('vkey-back'),
                height: keyHeight,
                onPressed: enabled && entry.digits.isNotEmpty ? entry.backspace : null,
                child: const Text('지우기', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: keyHeight,
                child: FilledButton(
                  key: const Key('vkey-submit'),
                  onPressed: enabled && entry.isComplete ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.strike,
                    foregroundColor: AppColors.onStrike,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    submitLabel,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.height,
    required this.onPressed,
    required this.child,
  });

  final double height;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.panel,
          foregroundColor: AppColors.chalk,
          disabledBackgroundColor: AppColors.ground,
          disabledForegroundColor: AppColors.disabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: onPressed != null ? AppColors.line : AppColors.panel,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
