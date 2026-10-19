import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/four_s_api.dart';
import '../game/game_logic.dart';
import '../game/solo_game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// 혼자 하기: 숨겨진 네 자리 숫자를 맞힐 때까지 던진다.
class SoloPlayScreen extends StatefulWidget {
  const SoloPlayScreen({super.key, this.game});

  /// 테스트처럼 게임을 미리 만들어 넘기고 싶을 때 쓴다.
  final SoloGame? game;

  @override
  State<SoloPlayScreen> createState() => _SoloPlayScreenState();
}

class _SoloPlayScreenState extends State<SoloPlayScreen> {
  SoloGame? _ownGame;
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'solo-keyboard');
  bool _navigated = false;

  SoloGame get _game => widget.game ?? _ownGame!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.game == null && _ownGame == null) {
      _ownGame = SoloGame(api: ApiScope.of(context))..start();
    }
  }

  @override
  void dispose() {
    _ownGame?.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await _game.submit();
    if (!mounted) return;
    if (result == null) {
      final error = _game.error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    if (_game.isWon) {
      _finish();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _finish() async {
    if (_navigated) return;
    _navigated = true;
    final summary = SoloSummary(
      tries: _game.tries,
      answer: _game.answer!,
      elapsed: _game.elapsed,
      gameId: _game.gameId,
    );
    // 마지막 판정을 잠깐 보여준 뒤 결과 화면으로.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(summary: summary)),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _game.backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      _game.press(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: PhoneFrame(
        child: ListenableBuilder(
          listenable: _game,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(tries: _game.tries),
                if (!_game.isOnline && _game.phase != SoloPhase.starting)
                  _OfflineNote(fellBack: _game.fellBackOffline),
                const SizedBox(height: 12),
                Expanded(
                  child: _HistoryBoard(game: _game, controller: _scroll),
                ),
                const SizedBox(height: 16),
                _InputSlots(input: _game.input),
                const SizedBox(height: 14),
                _Keypad(game: _game, onSubmit: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tries});

  final int tries;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '홈으로',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.chalk,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        const Expanded(
          child: Text(
            '혼자 하기 · 4자리',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$tries회',
            key: const Key('tries-count'),
            textAlign: TextAlign.right,
            style: AppFonts.mono(
              const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.fellBack});

  final bool fellBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        fellBack
            ? '서버에 연결할 수 없어 오프라인으로 진행해요 · 랭킹 등록 불가'
            : '오프라인 모드 · 랭킹 등록 불가',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _HistoryBoard extends StatelessWidget {
  const _HistoryBoard({required this.game, required this.controller});

  final SoloGame game;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final history = game.history;
    final Widget body;
    if (game.phase == SoloPhase.starting) {
      body = const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.strike,
          ),
        ),
      );
    } else if (history.isEmpty) {
      body = const Center(
        child: Text(
          '아래 키패드로 숫자 4개를 입력해 보세요',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      );
    } else {
      body = ListView.separated(
        controller: controller,
        itemCount: history.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: AppColors.panel),
        itemBuilder: (context, i) =>
            _HistoryRow(number: i + 1, record: history[i]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.board,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 40, child: _HeadText('회')),
                Expanded(child: _HeadText('추리')),
                _HeadText('결과'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _HeadText extends StatelessWidget {
  const _HeadText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.number, required this.record});

  final int number;
  final GuessRecord record;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$number',
              style: AppFonts.mono(
                const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ),
          ),
          Expanded(
            child: Text(
              record.guess,
              style: AppFonts.mono(
                const TextStyle(
                  fontSize: 22,
                  letterSpacing: 6,
                  color: AppColors.chalk,
                ),
              ),
            ),
          ),
          ResultBadges(result: record.result),
        ],
      ),
    );
  }
}

class _InputSlots extends StatelessWidget {
  const _InputSlots({required this.input});

  final List<String> input;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '입력한 숫자 ${input.isEmpty ? '없음' : input.join(' ')}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < GameRules.digits; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            ScoreboardDigit(
              text: i < input.length ? input[i] : '',
              width: 60,
              height: 70,
              fontSize: 34,
              active: i == input.length,
            ),
          ],
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.game, required this.onSubmit});

  final SoloGame game;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final enabled = game.isPlaying && !game.busy;

    Widget row(List<String> digits) => Row(
          children: [
            for (var i = 0; i < digits.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _DigitKey(
                  digit: digits[i],
                  enabled: enabled && !game.isUsed(digits[i]),
                  onPressed: () => game.press(digits[i]),
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
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('key-back'),
                  onPressed:
                      enabled && game.input.isNotEmpty ? game.backspace : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.panel,
                    foregroundColor: AppColors.chalk,
                    disabledBackgroundColor: AppColors.ground,
                    disabledForegroundColor: AppColors.disabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                  ),
                  child: const Text('지우기', style: TextStyle(fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  key: const Key('key-submit'),
                  onPressed: game.canSubmit ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.strike,
                    foregroundColor: AppColors.onStrike,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: game.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.muted,
                          ),
                        )
                      : const Text(
                          '던지기',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
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

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.enabled,
    required this.onPressed,
  });

  final String digit;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        key: Key('key-$digit'),
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.panel,
          foregroundColor: AppColors.chalk,
          disabledBackgroundColor: AppColors.ground,
          disabledForegroundColor: AppColors.disabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: enabled ? AppColors.line : AppColors.panel),
          ),
        ),
        child: Text(digit, style: AppFonts.mono(const TextStyle(fontSize: 22))),
      ),
    );
  }
}
