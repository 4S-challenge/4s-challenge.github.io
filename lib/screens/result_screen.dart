import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'solo_play_screen.dart';

/// 혼자 하기 한 판의 결과.
class SoloSummary {
  const SoloSummary({
    required this.won,
    required this.tries,
    required this.secret,
    required this.elapsed,
  });

  final bool won;
  final int tries;
  final String secret;
  final Duration elapsed;

  String get shareText => won
      ? '4S 챌린지 - 숫자야구\n$tries번 만에 4S 달성! (${formatDuration(elapsed)})\nhttps://4s-challenge.github.io'
      : '4S 챌린지 - 숫자야구\n${GameRules.maxTries}번 안에 못 맞혔어요. 도전해 보세요!\nhttps://4s-challenge.github.io';
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.summary});

  final SoloSummary summary;

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: summary.shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('결과를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final won = summary.won;
    return PhoneFrame(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 80).clamp(0.0, double.infinity)),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'GAME SET',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, letterSpacing: 3, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    won ? '4S 달성!' : '아쉽게 실패',
                    textAlign: TextAlign.center,
                    style: AppFonts.display(
                      TextStyle(
                        fontSize: 56,
                        color: won ? AppColors.strike : AppColors.chalk,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    won
                        ? '${summary.tries}번 만에 맞혔어요'
                        : '${GameRules.maxTries}번 안에 맞히지 못했어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  _Card(
                    child: Column(
                      children: [
                        const Text('정답', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < summary.secret.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              ScoreboardDigit(
                                text: summary.secret[i],
                                width: 52,
                                height: 64,
                                fontSize: 32,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      children: [
                        _StatLine(label: '시도 횟수', value: '${summary.tries}회'),
                        const SizedBox(height: 10),
                        _StatLine(label: '걸린 시간', value: formatDuration(summary.elapsed)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  BigButton(
                    label: '한 판 더',
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const SoloPlayScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          label: '결과 복사',
                          icon: Icons.ios_share,
                          style: BigButtonStyle.tonal,
                          height: 52,
                          onPressed: () => _share(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BigButton(
                          label: '홈으로',
                          style: BigButtonStyle.tonal,
                          height: 52,
                          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(value, style: AppFonts.mono(const TextStyle(fontSize: 15, color: AppColors.chalk))),
      ],
    );
  }
}
