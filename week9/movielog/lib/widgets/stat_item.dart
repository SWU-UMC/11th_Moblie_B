import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 통계 카드 한 칸 (Figma W8-06: 114 x 86, radius 11, 테두리 #E4DAF1)
class StatItem extends StatelessWidget {
  const StatItem({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.only(top: 19),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        border: Border.all(color: AppColors.statBorder),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.violet,
            ),
          ),
        ],
      ),
    );
  }
}
