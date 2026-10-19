import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 입력을 대문자로 바꾼다.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// 영문 대문자(와 선택적으로 숫자)만 [length]글자까지 받는 큰 전광판 스타일 입력칸.
class ScoreboardTextField extends StatelessWidget {
  const ScoreboardTextField({
    super.key,
    required this.controller,
    required this.length,
    required this.hint,
    this.allowDigits = false,
    this.enabled = true,
    this.onSubmitted,
    this.width = 200,
  });

  final TextEditingController controller;
  final int length;
  final String hint;
  final bool allowDigits;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final double width;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        );
    final style = AppFonts.mono(
      const TextStyle(fontSize: 32, letterSpacing: 12, color: AppColors.strike),
    );
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        autocorrect: false,
        enableSuggestions: false,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        inputFormatters: [
          const UpperCaseTextFormatter(),
          FilteringTextInputFormatter.allow(RegExp(allowDigits ? '[A-Z0-9]' : '[A-Z]')),
          LengthLimitingTextInputFormatter(length),
        ],
        style: style,
        cursorColor: AppColors.strike,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: AppColors.disabled),
          counterText: '',
          filled: true,
          fillColor: AppColors.board,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: border(AppColors.line),
          focusedBorder: border(AppColors.strike),
          disabledBorder: border(AppColors.line),
        ),
      ),
    );
  }
}
