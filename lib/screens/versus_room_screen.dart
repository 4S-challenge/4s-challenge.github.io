import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/four_s_api.dart';
import '../game/solo_game.dart';
import '../theme/app_theme.dart';
import '../versus/versus_models.dart';
import '../share/link_sharer.dart';
import '../versus/versus_session.dart';
import '../widgets/common.dart';
import '../widgets/digit_pad.dart';
import '../widgets/history.dart';

const _shareBase = 'https://4s-challenge.github.io/';

String roomShareLink(String code) => '$_shareBase?room=$code';

/// 대결방: 대기 → 숫자 정하기 → 대결 → 결과를 한 화면에서 단계별로 보여준다.
class VersusRoomScreen extends StatefulWidget {
  const VersusRoomScreen({
    super.key,
    required this.code,
    required this.name,
    this.session,
  });

  final String code;
  final String name;

  /// 테스트에서 미리 만든 세션을 넘길 때.
  final VersusSession? session;

  @override
  State<VersusRoomScreen> createState() => _VersusRoomScreenState();
}

class _VersusRoomScreenState extends State<VersusRoomScreen> {
  VersusSession? _session;
  bool _ownsSession = false;
  final _entry = DigitEntry();
  final _focus = FocusNode(debugLabel: 'versus-keyboard');
  StreamSubscription<String>? _noticeSub;
  Timer? _ticker;
  bool _showOpponentGuesses = false;
  int _seenMyGuesses = 0;
  int _seenRound = 0;
  VersusPhase? _seenPhase;

  VersusSession get _s => _session!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    var session = widget.session;
    if (session == null) {
      final api = ApiScope.of(context);
      if (api == null) return;
      session = VersusSession(
        code: widget.code,
        name: widget.name,
        socketUri: (playerId) =>
            api.roomSocketUri(widget.code, name: widget.name, playerId: playerId),
        connector: api.socketConnector,
      );
      _ownsSession = true;
      session.start();
    }
    _session = session;
    session.addListener(_onSessionChanged);
    _noticeSub = session.notices.listen(_showNotice);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _session?.snapshot?.phase == VersusPhase.playing) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noticeSub?.cancel();
    _session?.removeListener(_onSessionChanged);
    if (_ownsSession) _session?.dispose();
    _entry.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 서버 상태가 바뀔 때 입력칸을 정리한다.
  void _onSessionChanged() {
    final snap = _s.snapshot;
    if (snap == null) return;
    final newRound = snap.round != _seenRound;
    final phaseChanged = snap.phase != _seenPhase;
    final myGuesses = snap.me.guesses.length;
    if (newRound || phaseChanged || myGuesses > _seenMyGuesses) {
      _entry.clear();
    }
    if (newRound) _showOpponentGuesses = false;
    _seenRound = snap.round;
    _seenPhase = snap.phase;
    _seenMyGuesses = myGuesses;
    if (mounted) setState(() {});
  }

  void _submit() {
    final snap = _s.snapshot;
    if (snap == null || !_entry.isComplete) return;
    switch (snap.phase) {
      case VersusPhase.setting:
        if (snap.me.secret == null) _s.setSecret(_entry.value);
      case VersusPhase.playing:
        if (snap.myTurn) _s.guess(_entry.value);
      default:
        break;
    }
  }

  bool get _canType {
    final snap = _s.snapshot;
    if (snap == null || _s.status != VersusStatus.open) return false;
    return (snap.phase == VersusPhase.setting && snap.me.secret == null) || snap.myTurn;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!_canType) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _entry.backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      _entry.press(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _requestLeave() async {
    final snap = _session?.snapshot;
    final inGame = snap != null &&
        _session?.fatalError == null &&
        (snap.phase == VersusPhase.setting || snap.phase == VersusPhase.playing);
    if (inGame) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('방에서 나갈까요?'),
          content: const Text('대결 중에 나가면 기권패로 처리돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속하기', style: TextStyle(color: AppColors.chalk)),
            ),
            TextButton(
              key: const Key('versus-leave-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('나가기', style: TextStyle(color: AppColors.out)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _session?.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showNotice(done);
  }

  /// 초대하기: 기기 공유 창, 없으면 링크 복사.
  Future<void> _invite(String code) async {
    final outcome = await linkSharer.share(
      title: '4S 챌린지 - 숫자야구',
      text: '4S 챌린지 - 숫자야구 대결해요! (방 코드 $code)',
      url: roomShareLink(code),
    );
    if (outcome == ShareOutcome.copied) {
      _showNotice('초대 링크를 복사했어요. 친구에게 붙여넣어 보내 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeave();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: PhoneFrame(
          child: session == null
              ? const _CenterMessage(text: '대결 서버를 준비 중이에요')
              : ListenableBuilder(
                  listenable: Listenable.merge([session, _entry]),
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(code: widget.code, onClose: _requestLeave),
                      if (session.status == VersusStatus.reconnecting)
                        const _Banner(text: '연결이 끊겨 다시 연결하는 중…'),
                      Expanded(child: _body(session)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _body(VersusSession session) {
    final fatal = session.fatalError;
    if (fatal != null) {
      return _CenterMessage(
        text: fatal,
        action: BigButton(
          label: '돌아가기',
          style: BigButtonStyle.tonal,
          height: 52,
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
    final snap = session.snapshot;
    if (snap == null) {
      return _CenterMessage(text: '방 ${widget.code}에 들어가는 중…', loading: true);
    }
    return switch (snap.phase) {
      VersusPhase.waiting => _waiting(snap),
      VersusPhase.setting => _setting(snap),
      VersusPhase.playing => _playing(session, snap),
      VersusPhase.finished => _finished(snap),
    };
  }

  // ── 대기 ─────────────────────────────────────────────

  Widget _waiting(VersusSnapshot snap) {
    final code = snap.code.isEmpty ? widget.code : snap.code;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '방 코드',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            key: const Key('versus-room-code'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < code.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                ScoreboardDigit(text: code[i], width: 56, height: 68, fontSize: 32),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: '코드 복사',
                  icon: Icons.copy,
                  style: BigButtonStyle.tonal,
                  height: 48,
                  onPressed: () => _copy(code, '방 코드를 복사했어요'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BigButton(
                  key: const Key('versus-invite'),
                  // 공유 창을 쓸 수 있으면 '초대하기', 없으면(PC 일부, 카카오톡 안 브라우저) '링크 복사'
                  label: linkSharer.canShare ? '초대하기' : '링크 복사',
                  icon: linkSharer.canShare ? Icons.ios_share : Icons.link,
                  style: BigButtonStyle.tonal,
                  height: 48,
                  onPressed: () => _invite(code),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('참가자', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 8),
          _PlayerTile(name: snap.me.name, status: '나', highlight: true),
          const SizedBox(height: 8),
          const _EmptySeat(),
          const SizedBox(height: 20),
          const Text(
            '친구에게 방 코드나 링크를 보내 주세요.\n친구가 들어오면 각자 비밀 숫자를 정하고 시작해요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── 숫자 정하기 ──────────────────────────────────────

  Widget _setting(VersusSnapshot snap) {
    final opp = snap.opponent;
    final mine = snap.me.secret;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PlayerTile(
                  name: snap.me.name,
                  status: mine == null ? '정하는 중' : '준비 완료',
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlayerTile(
                  name: opp?.name ?? '',
                  status: opp == null
                      ? ''
                      : !opp.connected
                          ? '연결 끊김'
                          : opp.ready
                              ? '준비 완료'
                              : '정하는 중',
                ),
              ),
            ],
          ),
          if (snap.round > 1) ...[
            const SizedBox(height: 8),
            Text(
              '${snap.round}번째 판',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const Spacer(),
          if (mine == null) ...[
            const Text(
              '상대가 맞힐 내 비밀 숫자를 정하세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '서로 다른 숫자 4개 · 0으로 시작해도 돼요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            DigitSlots(digits: _entry.digits),
            const Spacer(),
            DigitPad(
              entry: _entry,
              enabled: _s.status == VersusStatus.open,
              submitLabel: '이 숫자로 정하기',
              onSubmit: _submit,
            ),
          ] else ...[
            const Text(
              '내 비밀 숫자',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            DigitSlots(digits: mine.split(''), showCursor: false),
            const SizedBox(height: 28),
            const _Waiting(text: '상대가 숫자를 정하는 중…'),
            const Spacer(flex: 2),
          ],
        ],
      ),
    );
  }

  // ── 대결 ────────────────────────────────────────────

  Widget _playing(VersusSession session, VersusSnapshot snap) {
    final opp = snap.opponent;
    final myTurn = snap.myTurn;
    final remaining = session.remaining ?? Duration.zero;
    final records = _showOpponentGuesses ? (opp?.guesses ?? const <GuessRecord>[]) : snap.me.guesses;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Scoreboard(
            myName: snap.me.name,
            myTries: snap.me.guesses.length,
            oppName: opp?.name ?? '',
            oppTries: opp?.guesses.length ?? 0,
            oppConnected: opp?.connected ?? false,
            myTurn: myTurn,
            remaining: remaining,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('내 비밀 숫자', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const Spacer(),
              Text(
                snap.me.secret ?? '',
                style: AppFonts.mono(
                  const TextStyle(fontSize: 16, letterSpacing: 6, color: AppColors.chalk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Tabs(
            left: '내 추리 ${snap.me.guesses.length}',
            right: '상대 추리 ${opp?.guesses.length ?? 0}',
            rightSelected: _showOpponentGuesses,
            onChanged: (right) => setState(() => _showOpponentGuesses = right),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _Board(
              records: records,
              empty: _showOpponentGuesses ? '상대가 아직 던지지 않았어요' : '숫자 4개를 골라 던져 보세요',
            ),
          ),
          const SizedBox(height: 12),
          DigitSlots(digits: _entry.digits, size: 54, showCursor: myTurn),
          const SizedBox(height: 12),
          DigitPad(
            entry: _entry,
            enabled: myTurn && session.status == VersusStatus.open,
            submitLabel: myTurn ? '던지기' : '상대 차례',
            onSubmit: _submit,
            keyHeight: 48,
          ),
        ],
      ),
    );
  }

  // ── 결과 ────────────────────────────────────────────

  Widget _finished(VersusSnapshot snap) {
    final opp = snap.opponent;
    final won = snap.iWon;
    final String detail;
    if (snap.byForfeit) {
      detail = won ? '상대가 방을 나가서 이겼어요' : '기권했어요';
    } else {
      detail = won
          ? '${snap.me.guesses.length}번 만에 상대 숫자를 맞혔어요'
          : '상대가 ${opp?.guesses.length ?? 0}번 만에 내 숫자를 맞혔어요';
    }

    final oppLeft = opp == null || opp.left;
    final String rematchLabel;
    if (opp == null || opp.left) {
      rematchLabel = '상대가 나갔어요';
    } else if (snap.me.rematch) {
      rematchLabel = '상대를 기다리는 중…';
    } else if (opp.rematch) {
      rematchLabel = '한 판 더 (상대가 기다려요)';
    } else {
      rematchLabel = '한 판 더';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'GAME SET',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, letterSpacing: 3, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  won ? '승리!' : '패배',
                  key: const Key('versus-outcome'),
                  textAlign: TextAlign.center,
                  style: AppFonts.display(
                    TextStyle(
                      fontSize: 56,
                      height: 1.15,
                      color: won ? AppColors.strike : AppColors.chalk,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(detail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SecretCard(
                        label: '${opp?.name ?? '상대'}의 숫자',
                        secret: opp?.secret,
                        tries: '내 시도 ${snap.me.guesses.length}회',
                        color: AppColors.strike,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecretCard(
                        label: '내 숫자',
                        secret: snap.me.secret,
                        tries: '상대 시도 ${opp?.guesses.length ?? 0}회',
                        color: AppColors.ball,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Tabs(
                  left: '내 추리 ${snap.me.guesses.length}',
                  right: '상대 추리 ${opp?.guesses.length ?? 0}',
                  rightSelected: _showOpponentGuesses,
                  onChanged: (right) => setState(() => _showOpponentGuesses = right),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _Board(
                    records: _showOpponentGuesses
                        ? (opp?.guesses ?? const <GuessRecord>[])
                        : snap.me.guesses,
                    empty: '기록이 없어요',
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: const BoxDecoration(
            color: AppColors.ground,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BigButton(
                key: const Key('versus-rematch'),
                label: rematchLabel,
                onPressed: oppLeft || snap.me.rematch || _s.status != VersusStatus.open
                    ? null
                    : _s.rematch,
              ),
              const SizedBox(height: 10),
              BigButton(
                label: '나가기',
                style: BigButtonStyle.tonal,
                height: 52,
                onPressed: _requestLeave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 작은 위젯들 ───────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.code, required this.onClose});

  final String code;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('versus-close'),
            tooltip: '나가기',
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: AppColors.chalk,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          Expanded(
            child: Text(
              '친구와 대결 · $code',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.out,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.onOut, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.text, this.loading = false, this.action});

  final String text;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (loading) ...[
              const Center(child: CircularProgressIndicator(color: AppColors.strike)),
              const SizedBox(height: 16),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.muted),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.name, required this.status, this.highlight = false});

  final String name;
  final String status;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            name,
            style: AppFonts.mono(
              TextStyle(
                fontSize: 20,
                letterSpacing: 3,
                color: highlight ? AppColors.strike : AppColors.chalk,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              status,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 2),
      ),
      child: const _Waiting(text: '상대를 기다리는 중…'),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.myName,
    required this.myTries,
    required this.oppName,
    required this.oppTries,
    required this.oppConnected,
    required this.myTurn,
    required this.remaining,
  });

  final String myName;
  final int myTries;
  final String oppName;
  final int oppTries;
  final bool oppConnected;
  final bool myTurn;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final urgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.board,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('나', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(
                  myName,
                  style: AppFonts.mono(const TextStyle(fontSize: 18, letterSpacing: 2)),
                ),
                Text(
                  '$myTries회 시도',
                  style: AppFonts.mono(const TextStyle(fontSize: 13, color: AppColors.strike)),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '0:${seconds.toString().padLeft(2, '0')}',
                key: const Key('versus-timer'),
                style: AppFonts.mono(
                  TextStyle(
                    fontSize: 26,
                    color: urgent ? AppColors.out : AppColors.strike,
                  ),
                ),
              ),
              Container(
                key: const Key('versus-turn'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: myTurn ? AppColors.strike : AppColors.panel,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  myTurn ? '내 차례' : '상대 차례',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: myTurn ? AppColors.onStrike : AppColors.chalk,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  oppConnected ? '상대' : '상대 · 연결 끊김',
                  style: TextStyle(
                    fontSize: 12,
                    color: oppConnected ? AppColors.muted : AppColors.out,
                  ),
                ),
                Text(
                  oppName,
                  style: AppFonts.mono(const TextStyle(fontSize: 18, letterSpacing: 2)),
                ),
                Text(
                  '$oppTries회 시도',
                  style: AppFonts.mono(const TextStyle(fontSize: 13, color: AppColors.ball)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: SizedBox(
            height: 44,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: selected ? AppColors.chalk : Colors.transparent,
                foregroundColor: selected ? AppColors.ground : AppColors.chalk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                textStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              child: Text(label),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab(left, !rightSelected, () => onChanged(false)),
          const SizedBox(width: 4),
          tab(right, rightSelected, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.records, required this.empty});

  final List<GuessRecord> records;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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
            child: records.isEmpty
                ? Center(
                    child: Text(empty, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  )
                : HistoryList(records: records, highlightWin: true),
          ),
        ],
      ),
    );
  }
}

class _SecretCard extends StatelessWidget {
  const _SecretCard({
    required this.label,
    required this.secret,
    required this.tries,
    required this.color,
  });

  final String label;
  final String? secret;
  final String tries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            secret ?? '????',
            style: AppFonts.mono(TextStyle(fontSize: 28, letterSpacing: 6, color: color)),
          ),
          const SizedBox(height: 6),
          Text(tries, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
