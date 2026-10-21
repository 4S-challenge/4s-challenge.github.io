import 'package:flutter/material.dart';

import '../api/four_s_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 랭킹: 적은 시도 → 짧은 시간 순.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, this.highlightId});

  /// 방금 등록한 기록. 목록에서 강조한다.
  final int? highlightId;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  Future<List<RankingEntry>>? _future;
  FourSApi? _api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = ApiScope.of(context);
    if (_future == null || api != _api) {
      _api = api;
      _future = api?.rankings();
    }
  }

  Future<void> _reload() async {
    final api = _api;
    if (api == null) return;
    final next = api.rankings();
    setState(() => _future = next);
    try {
      await next;
    } on ApiException {
      // 화면에서 오류를 보여준다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      showAd: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '뒤로',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppColors.chalk,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                const Expanded(
                  child: Text(
                    '랭킹',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '적은 시도 순, 같으면 빨리 맞힌 순',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.board,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _api == null
                    ? const _Message(text: '랭킹 서버를 준비 중이에요')
                    : FutureBuilder<List<RankingEntry>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.strike,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            final error = snapshot.error;
                            return _Message(
                              text: error is ApiException
                                  ? error.message
                                  : '랭킹을 불러오지 못했어요',
                              onRetry: _reload,
                            );
                          }
                          final entries = snapshot.data ?? const [];
                          if (entries.isEmpty) {
                            return const _Message(
                              text: '아직 등록된 기록이 없어요.\n첫 번째 주인공이 되어 보세요!',
                            );
                          }
                          return RefreshIndicator(
                            color: AppColors.strike,
                            onRefresh: _reload,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: entries.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                height: 1,
                                color: AppColors.panel,
                              ),
                              itemBuilder: (context, i) => _RankRow(
                                entry: entries[i],
                                highlight: entries[i].id == widget.highlightId,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.highlight});

  final RankingEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final podium = entry.rank <= 3;
    return Container(
      height: 56,
      color: highlight ? AppColors.panelHigh : null,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${entry.rank}',
              style: AppFonts.mono(
                TextStyle(
                  fontSize: 18,
                  color: podium ? AppColors.strike : AppColors.muted,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.initials,
              style: AppFonts.mono(
                const TextStyle(
                  fontSize: 22,
                  letterSpacing: 4,
                  color: AppColors.chalk,
                ),
              ),
            ),
          ),
          Text(
            '${entry.tries}회',
            style: AppFonts.mono(
              const TextStyle(fontSize: 16, color: AppColors.chalk),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            child: Text(
              formatDuration(entry.duration),
              textAlign: TextAlign.right,
              style: AppFonts.mono(
                const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.chalk,
                  side: const BorderSide(color: AppColors.line),
                  minimumSize: const Size(120, 44),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
