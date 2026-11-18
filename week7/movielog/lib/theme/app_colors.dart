import 'package:flutter/material.dart';

/// Figma 기준 색상
abstract final class AppColors {
  static const violet = Color(0xFF6750A4);
  static const violetDark = Color(0xFF4F378A);
  static const violetLight = Color(0xFFE9DDFF);
  static const violetBorder = Color(0xFFD0BCFF);

  static const warmWhite = Color(0xFFFAF9F5);
  static const cardBackground = Color(0xFFF5F3F0);
  static const white = Color(0xFFFFFFFF);

  static const black = Color(0xFF1D1B20);
  static const gray = Color(0xFF494551);

  // 2주차 Form
  static const inputBorder = Color(0xFFCBC4D2);
  static const hint = Color(0xFF7A7582);
  static const error = Color(0xFFB3261E);
  static const errorContainer = Color(0xFFFFDAD6);
  static const disabledButton = Color(0xFFCCC2DC);

  // 3주차 영화
  static const divider = Color(0xFFE6E0E9);
  static const posterBadge = Color(0xB31D1B20);

  // 6주차 중복 확인 (사용 가능)
  static const success = Color(0xFF2E7D32);

  // 7주차 (Figma W7 프레임 값)
  static const screenBackground = Color(0xFFFEFCF9);
  static const textPrimary = Color(0xFF25232A);
  static const textSecondary = Color(0xFF655F6C);
  static const cardBorder = Color(0xFFD9D3E1);
  static const posterPlaceholder = Color(0xFFD8D2E0);

  /// 취소·수정 버튼 배경
  static const tonalContainer = Color(0xFFF0EAF8);

  /// 카드 삭제 버튼 배경
  static const dangerContainer = Color(0xFFFFF2F0);

  /// 코멘트 입력칸
  static const fieldBackground = Color(0xFFFAF8FD);
  static const fieldBorder = Color(0xFFD8D2E0);

  /// 선택 안 된 체크박스 테두리
  static const checkboxBorder = Color(0xFFAEA7B4);

  /// Dialog·다중 삭제 가림막 (#25232A 34%)
  static const barrier = Color(0x5725232A);
}
