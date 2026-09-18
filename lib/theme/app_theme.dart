import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.surfaceBase,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary500,
      primaryContainer: AppColors.primary100,
      secondary: AppColors.primary200,
      surface: AppColors.surfaceBase,
      surfaceVariant: AppColors.neutral200,
      outlineVariant: AppColors.neutral400,
      onSurface: AppColors.neutral900,
      outline: AppColors.primary500,
    ),
    
    textTheme: const TextTheme(
      headlineSmall: AppTextStyles.headlineSmall, // 이름
      titleLarge: AppTextStyles.titleLarge,       // 통계 숫자
      titleMedium: AppTextStyles.titleMedium,     // 장르 타이틀
      bodyMedium: AppTextStyles.bodyMedium,       // 본문
      labelLarge: AppTextStyles.labelLarge,       // 버튼/칩 텍스트
      labelSmall: AppTextStyles.labelSmall,       // 통계 라벨
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceBase,
      foregroundColor: AppColors.primary500,
      elevation: 0,
      centerTitle: false,
    ),
  );
}