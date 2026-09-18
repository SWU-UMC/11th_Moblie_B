import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary100 = Color(0xFFF3EFFF); // 장르 칩 배경색 (연한 보라)
  static const primary200 = Color(0xFFE9DDFF); // 프로필 테두리
  static const primary500 = Color(0xFF6750A4); // 메인 보라 (글자, 버튼 테두리)
  
  // Surface Tones
  static const surfaceBase = Color(0xFFFAF9F5); // 전체 바탕
  static const neutral200 = Color(0xFFF5F3F0); // [추가] 한 단계 밝은 회색 (새 배경색)
  static const neutral400 = Color(0xFFEFEEEA);
  
  // Neutral Scale
  static const neutral900 = Color(0xFF1B1C1A); // 기본 텍스트 (검정)
}