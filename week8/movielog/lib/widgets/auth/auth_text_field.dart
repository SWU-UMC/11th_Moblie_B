import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// 로그인·프로필 수정 입력칸
/// Figma: 342 x 48, 흰 배경, 1px #D9D3E1, radius 8, 안쪽 16
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.errorText,
    this.maxLength,
    this.readOnly = false,
    this.hideErrorText = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  /// 서버 결과(중복 등) 문구, validator보다 우선
  final String? errorText;

  /// 글자 수 제한 (카운터는 안 보임)
  final int? maxLength;

  /// 이메일처럼 보여주기만 하는 칸 (회색 배경)
  final bool readOnly;

  /// 테두리만 빨갛게 하고 문구는 화면이 따로 그릴 때 (카운터랑 한 줄)
  final bool hideErrorText;

  static const _input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final outlineError = hideErrorText && errorText != null;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onChanged: onChanged,
      // hideErrorText면 문구 없이 테두리만 빨갛게 (아래에서 처리)
      forceErrorText: hideErrorText ? null : errorText,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      // 비밀번호는 저장·로그 안 하고 자동완성만 허용
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      style: readOnly
          ? _input.copyWith(color: AppColors.textSecondary)
          : _input,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: _input.copyWith(color: AppColors.hint),
        counterText: '',
        errorStyle: const TextStyle(
          fontSize: 13,
          height: 1.25,
          color: AppColors.error,
        ),
        filled: true,
        fillColor: readOnly ? AppColors.readOnlyField : AppColors.white,
        isDense: true,
        constraints: const BoxConstraints(minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: _border(AppColors.cardBorder),
        enabledBorder: _border(
          outlineError ? AppColors.error : AppColors.cardBorder,
        ),
        disabledBorder: _border(AppColors.cardBorder),
        focusedBorder: _border(
          outlineError
              ? AppColors.error
              : (readOnly ? AppColors.cardBorder : AppColors.violet),
        ),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
      ),
    );
  }
}
