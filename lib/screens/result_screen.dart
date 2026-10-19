import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/four_s_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ranking_screen.dart';
import 'solo_play_screen.dart';

/// 혼자 하기 한 판의 결과.
class SoloSummary {
  const SoloSummary({
    required this.tries,
    required this.answer,
    required this.elapsed,
    this.gameId,
  });

  final int tries;
  final String answer;
  final Duration elapsed;

  /// 서버에서 판정한 게임이면 ID가 있고, 랭킹에 등록할 수 있다.
  final String? gameId;

  String get shareText => '4S 챌린지 - 숫자야구\n'
      '$tries번 만에 4S 달성! (${formatDuration(elapsed)})\n'
      'https://4s-challenge.github.io';
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
    final api = ApiScope.of(context);
    final gameId = summary.gameId;

    return PhoneFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GAME SET',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 3,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '4S 달성!',
              textAlign: TextAlign.center,
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 56,
                  color: AppColors.strike,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.tries}번 만에 맞혔어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _Card(
              child: Column(
                children: [
                  const Text(
                    '정답',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < summary.answer.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        ScoreboardDigit(
                          text: summary.answer[i],
                          width: 52,
                          height: 64,
                          fontSize: 32,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatLine(label: '시도 횟수', value: '${summary.tries}회'),
                  const SizedBox(height: 10),
                  _StatLine(
                    label: '걸린 시간',
                    value: formatDuration(summary.elapsed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (api != null && gameId != null)
              RankingForm(api: api, gameId: gameId)
            else
              const _Card(
                child: Text(
                  '오프라인으로 플레이한 게임은 랭킹에 등록할 수 없어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 28),
            BigButton(
              label: '한 판 더',
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const SoloPlayScreen(),
                ),
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
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 영문 대문자 3글자 이니셜로 랭킹에 등록하는 칸.
class RankingForm extends StatefulWidget {
  const RankingForm({super.key, required this.api, required this.gameId});

  final FourSApi api;
  final String gameId;

  @override
  State<RankingForm> createState() => _RankingFormState();
}

class _RankingFormState extends State<RankingForm> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;
  RankingEntry? _registered;

  static final _initialsPattern = RegExp(r'^[A-Z]{3}$');

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _initialsPattern.hasMatch(_controller.text);

  Future<void> _submit() async {
    if (!_valid || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final entry =
          await widget.api.submitRanking(widget.gameId, _controller.text);
      if (!mounted) return;
      setState(() => _registered = entry);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openRanking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RankingScreen(highlightId: _registered?.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registered = _registered;
    if (registered != null) {
      return _Card(
        child: Column(
          children: [
            Text(
              '${registered.rank}위',
              key: const Key('registered-rank'),
              style: AppFonts.display(
                const TextStyle(fontSize: 40, color: AppColors.strike),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${registered.initials} 이름으로 랭킹에 등록했어요',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            BigButton(
              label: '랭킹 보기',
              icon: Icons.emoji_events_outlined,
              style: BigButtonStyle.outlined,
              height: 52,
              onPressed: _openRanking,
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '랭킹에 이름 남기기',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            '영문 대문자 3글자',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 200,
              child: TextField(
                key: const Key('initials-field'),
                controller: _controller,
                enabled: !_sending,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                inputFormatters: [
                  const UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp('[A-Z]')),
                  LengthLimitingTextInputFormatter(3),
                ],
                style: AppFonts.mono(
                  const TextStyle(
                    fontSize: 34,
                    letterSpacing: 14,
                    color: AppColors.strike,
                  ),
                ),
                cursorColor: AppColors.strike,
                decoration: InputDecoration(
                  hintText: 'AAA',
                  hintStyle: AppFonts.mono(
                    const TextStyle(
                      fontSize: 34,
                      letterSpacing: 14,
                      color: AppColors.disabled,
                    ),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.board,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.line, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.strike, width: 2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.line, width: 2),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.out),
            ),
          ],
          const SizedBox(height: 12),
          BigButton(
            key: const Key('rank-submit'),
            label: _sending ? '등록 중…' : '랭킹 등록',
            height: 52,
            onPressed: _valid && !_sending ? _submit : null,
          ),
        ],
      ),
    );
  }
}

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
        Text(
          value,
          style: AppFonts.mono(
            const TextStyle(fontSize: 15, color: AppColors.chalk),
          ),
        ),
      ],
    );
  }
}
