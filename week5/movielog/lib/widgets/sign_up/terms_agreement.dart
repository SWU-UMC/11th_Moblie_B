import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 필수 약관 동의 Checkbox (문구를 눌러도 체크됩니다)
class TermsAgreement extends StatelessWidget {
  const TermsAgreement({
    super.key,
    required this.agreed,
    required this.onChanged,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!agreed),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: agreed,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: AppColors.violet,
              side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Text('필수 약관에 동의합니다', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
