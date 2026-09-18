import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // [수정] 프로필 이름용: 크고 두껍게
  static const headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.neutral900);
  
  // [수정] 통계 숫자용: 크고 두껍게, 메인 보라색 적용
  static const titleLarge = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary500);

  // [수정] 버튼 및 장르 칩 텍스트용: 두껍게, 메인 보라색 적용
  static const labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary500);

  // 본문 설명용
  static const bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.neutral900, height: 1.5);
  
  // '선호하는 장르' 타이틀용
  static const titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900);

  // 통계 항목 라벨(본 영화 등)용
  static const labelSmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral900);
}