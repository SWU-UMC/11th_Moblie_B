import 'package:flutter/material.dart';

import '../models/profile_stat.dart';
import 'stat_item.dart';

/// 통계 항목들을 같은 너비로 가로 배치
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: StatItem(label: stats[i].label, value: stats[i].value),
          ),
        ],
      ],
    );
  }
}
