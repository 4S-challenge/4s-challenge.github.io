import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ranking_screen.dart';
import 'solo_play_screen.dart';
import 'versus_lobby_screen.dart';

/// 스토어 등록에도 쓰는 개인정보처리방침 주소.
final privacyPolicyUrl = Uri.parse('https://4s-challenge.ohsangplay.com/privacy.html');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialRoomCode});

  /// 초대 링크(?room=XXXX)로 들어왔을 때의 방 코드. 있으면 바로 대결 화면을 연다.
  final String? initialRoomCode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final code = widget.initialRoomCode;
    if (code != null && code.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openVersus(code);
      });
    }
  }

  void _openVersus([String? code]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VersusLobbyScreen(initialCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      showAd: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          // 아래 여백은 개인정보처리방침 버튼의 터치 영역(48)이 이미 있어 작게 둔다.
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 24).clamp(0.0, double.infinity)),
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
                    onPressed: _openVersus,
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
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => launchUrl(privacyPolicyUrl, mode: LaunchMode.externalApplication),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('개인정보처리방침', style: TextStyle(fontSize: 13)),
                    ),
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
