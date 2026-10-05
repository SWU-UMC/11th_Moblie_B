import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 공통 글자 스타일 (Figma Typography 기준)
abstract final class AppTextStyles {
  /// 시작 화면 제목
  static const headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 36 / 28,
    color: AppColors.black,
  );

  /// AppBar 제목, 닉네임
  static const titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 28 / 22,
    color: AppColors.black,
  );

  /// 섹션 제목, 프로필 수정 버튼
  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    color: AppColors.black,
  );

  /// 프로필 소개
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    color: AppColors.gray,
  );

  /// 시작 화면 설명
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.25,
    color: AppColors.gray,
  );

  /// 버튼 문구
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.1,
  );

  /// 통계 라벨, 장르 Chip
  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: AppColors.gray,
  );

  /// 시작 화면 상단 캡션
  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 16 / 11,
    letterSpacing: 0.55,
    color: AppColors.gray,
  );

  /// 통계 숫자
  static const statValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    color: AppColors.violetDark,
  );
}
