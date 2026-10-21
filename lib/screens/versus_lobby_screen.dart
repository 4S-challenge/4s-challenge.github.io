import 'package:flutter/material.dart';

import '../api/four_s_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/initials_input.dart';
import 'versus_room_screen.dart';

/// 친구와 대결: 방 만들기 / 방 코드로 들어가기.
class VersusLobbyScreen extends StatefulWidget {
  const VersusLobbyScreen({super.key, this.initialCode});

  /// 공유 링크(?room=XXXX)로 들어왔을 때 미리 채울 방 코드.
  final String? initialCode;

  /// 앱을 켜 둔 동안 마지막으로 쓴 이니셜을 기억한다.
  static String lastName = '';

  @override
  State<VersusLobbyScreen> createState() => _VersusLobbyScreenState();
}

class _VersusLobbyScreenState extends State<VersusLobbyScreen> {
  late final _name = TextEditingController(text: VersusLobbyScreen.lastName);
  late final _code = TextEditingController(
    text: (widget.initialCode ?? '').toUpperCase(),
  );
  bool _creating = false;
  String? _error;

  static final _namePattern = RegExp(r'^[A-Z]{3}$');
  static final _codePattern = RegExp(r'^[A-Z0-9]{4}$');

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _code.addListener(_changed);
  }

  void _changed() => setState(() => _error = null);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _nameOk => _namePattern.hasMatch(_name.text);

  bool get _codeOk => _codePattern.hasMatch(_code.text);

  void _enter(String code) {
    VersusLobbyScreen.lastName = _name.text;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VersusRoomScreen(code: code, name: _name.text),
      ),
    );
  }

  Future<void> _create(FourSApi api) async {
    if (!_nameOk || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final code = await api.createRoom();
      if (!mounted) return;
      _enter(code);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiScope.of(context);
    return PhoneFrame(
      showAd: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
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
                    '친구와 대결',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: api == null
                ? const Center(
                    child: Text(
                      '대결 서버를 준비 중이에요',
                      style: TextStyle(fontSize: 15, color: AppColors.muted),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '번갈아 한 번씩 던져서 상대 숫자를 먼저 맞히면 승리!\n차례마다 30초 안에 던져야 해요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '내 이니셜',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '영문 대문자 3글자 · 상대에게 보여요',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: ScoreboardTextField(
                            key: const Key('versus-name'),
                            controller: _name,
                            length: 3,
                            hint: 'AAA',
                          ),
                        ),
                        const SizedBox(height: 28),
                        BigButton(
                          key: const Key('versus-create'),
                          label: _creating ? '방 만드는 중…' : '방 만들기',
                          icon: Icons.add,
                          onPressed: _nameOk && !_creating ? () => _create(api) : null,
                        ),
                        const SizedBox(height: 28),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.line)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '또는 친구 방에 들어가기',
                                style: TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.line)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ScoreboardTextField(
                            key: const Key('versus-code'),
                            controller: _code,
                            length: 4,
                            hint: 'CODE',
                            allowDigits: true,
                            width: 240,
                            onSubmitted: (_) {
                              if (_nameOk && _codeOk) _enter(_code.text);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        BigButton(
                          key: const Key('versus-join'),
                          label: '입장',
                          style: BigButtonStyle.outlined,
                          onPressed: _nameOk && _codeOk ? () => _enter(_code.text) : null,
                        ),
                        if (!_nameOk && (_codeOk || _name.text.isNotEmpty)) ...[
                          const SizedBox(height: 10),
                          const Text(
                            '먼저 이니셜 3글자를 입력해 주세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.out),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
