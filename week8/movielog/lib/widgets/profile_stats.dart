import 'package:flutter/material.dart';

import '../models/profile_stat.dart';
import 'stat_item.dart';

/// 통계 칸들 같은 너비로 배치 (간격 8)
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
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
