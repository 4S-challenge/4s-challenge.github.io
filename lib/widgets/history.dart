import 'package:flutter/material.dart';

import '../game/solo_game.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// 기록표 머리글: 회 / 추리 / 결과.
class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: _HeadText('회')),
              Expanded(child: _HeadText('추리')),
              _HeadText('결과'),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.line),
      ],
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

/// 기록표 한 줄: 몇 번째 / 던진 숫자 / S·B·OUT.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.number,
    required this.record,
    this.highlight = false,
  });

  final int number;
  final GuessRecord record;

  /// 정답 줄처럼 눈에 띄게 할 때.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: highlight ? AppColors.panelHigh : null,
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

/// 기록 목록. [records] 순서대로 1회부터 번호를 붙인다.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.records,
    this.controller,
    this.highlightWin = false,
  });

  final List<GuessRecord> records;
  final ScrollController? controller;

  /// 정답(4S) 줄을 강조할지.
  final bool highlightWin;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      itemCount: records.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.panel),
      itemBuilder: (context, i) => HistoryRow(
        number: i + 1,
        record: records[i],
        highlight: highlightWin && records[i].result.isWin,
      ),
    );
  }
}
