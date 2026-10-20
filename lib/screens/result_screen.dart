import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/four_s_api.dart';
import '../game/solo_game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/history.dart';
import '../share/link_sharer.dart';
import '../widgets/initials_input.dart';
import 'ranking_screen.dart';
import 'solo_play_screen.dart';

/// 혼자 하기 한 판의 결과.
class SoloSummary {
  const SoloSummary({
    required this.tries,
    required this.answer,
    required this.elapsed,
    this.history = const [],
    this.gameId,
  });

  final int tries;

  /// 이번 판에 던진 숫자와 결과, 던진 순서대로.
  final List<GuessRecord> history;
  final String answer;
  final Duration elapsed;

  /// 서버에서 판정한 게임이면 ID가 있고, 랭킹에 등록할 수 있다.
  final String? gameId;

  /// 공유할 때 링크 앞에 붙는 글.
  String get shareMessage => '4S 챌린지 - 숫자야구\n'
      '$tries번 만에 4S 달성! (${formatDuration(elapsed)})';

  static const shareUrl = 'https://4s-challenge.github.io';

  /// 복사할 때 쓰는 전체 글 (글 + 링크).
  String get shareText => shareCopyText(shareMessage, shareUrl);
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.summary});

  final SoloSummary summary;

  /// 결과 공유: 기기 공유 창, 없으면 복사.
  Future<void> _share(BuildContext context) async {
    final outcome = await linkSharer.share(
      title: '4S 챌린지 - 숫자야구',
      text: summary.shareMessage,
      url: SoloSummary.shareUrl,
    );
    if (outcome != ShareOutcome.copied || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('결과를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiScope.of(context);
    final gameId = summary.gameId;

    return PhoneFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 위쪽 내용만 스크롤된다.
          Expanded(
            child: SingleChildScrollView(
              key: const Key('result-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoundRecord(summary: summary),
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
                ],
              ),
            ),
          ),
          // 버튼은 화면 아래에 고정한다.
          Container(
            key: const Key('result-actions'),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: const BoxDecoration(
              color: AppColors.ground,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        key: const Key('result-share'),
                        label: linkSharer.canShare ? '결과 공유' : '결과 복사',
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
        ],
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

/// 이번 판 기록: 시도 횟수, 걸린 시간, 던진 숫자 목록.
class _RoundRecord extends StatelessWidget {
  const _RoundRecord({required this.summary});

  final SoloSummary summary;

  @override
  Widget build(BuildContext context) {
    final history = summary.history;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '이번 판 기록',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          _StatLine(label: '시도 횟수', value: '${summary.tries}회'),
          const SizedBox(height: 10),
          _StatLine(label: '걸린 시간', value: formatDuration(summary.elapsed)),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '입력한 숫자',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const Key('history-expand'),
                  tooltip: '크게 보기',
                  onPressed: () => showHistoryDialog(context, summary),
                  icon: const Icon(Icons.open_in_full, size: 20),
                  color: AppColors.chalk,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              key: const Key('history-inline'),
              height: 230,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              decoration: BoxDecoration(
                color: AppColors.board,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HistoryHeader(),
                  Expanded(
                    child: HistoryList(records: history, highlightWin: true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 이번 판 기록만 크게 보여주는 팝업. 오른쪽 위 X로 닫는다.
Future<void> showHistoryDialog(BuildContext context, SoloSummary summary) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _HistoryDialog(summary: summary),
  );
}

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.summary});

  final SoloSummary summary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.ground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '이번 판 기록 · ${summary.tries}회',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('history-close'),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.chalk,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 12),
                child: Text(
                  '정답 ${summary.answer} · ${formatDuration(summary.elapsed)}',
                  style: AppFonts.mono(
                    const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  key: const Key('history-full'),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: BoxDecoration(
                    color: AppColors.board,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HistoryHeader(),
                      Expanded(
                        child: HistoryList(
                          records: summary.history,
                          highlightWin: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
