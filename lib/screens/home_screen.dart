import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ranking_screen.dart';
import 'solo_play_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what은 준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 44).clamp(0.0, double.infinity)),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '게임 규칙',
                      onPressed: () => showRulesSheet(context),
                      icon: const Icon(Icons.help_outline, color: AppColors.chalk),
                      iconSize: 26,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '4S 챌린지',
                    textAlign: TextAlign.center,
                    style: AppFonts.display(
                      const TextStyle(
                        fontSize: 52,
                        color: AppColors.chalk,
                        height: 1.1,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '숫자야구',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 6,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.board,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line, width: 2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScoreboardDigit(text: '?'),
                          SizedBox(width: 10),
                          ScoreboardDigit(text: '?'),
                          SizedBox(width: 10),
                          ScoreboardDigit(text: '?'),
                          SizedBox(width: 10),
                          ScoreboardDigit(text: '?'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '숨겨진 네 자리 숫자를 추리해 보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  BigButton(
                    label: '혼자 하기',
                    icon: Icons.person_outline,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SoloPlayScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BigButton(
                    label: '친구와 대결',
                    icon: Icons.groups_outlined,
                    style: BigButtonStyle.outlined,
                    onPressed: () => _comingSoon(context, '친구와 대결'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          label: '랭킹',
                          style: BigButtonStyle.tonal,
                          height: 52,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const RankingScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BigButton(
                          label: '게임 규칙',
                          style: BigButtonStyle.tonal,
                          height: 52,
                          onPressed: () => showRulesSheet(context),
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
