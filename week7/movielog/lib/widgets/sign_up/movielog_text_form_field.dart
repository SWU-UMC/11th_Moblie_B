import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 입력창 상태
enum FieldStatus { idle, error, valid }

/// 공통 입력창 (라벨 + TextFormField)
/// status에 따라 테두리/배경/아이콘 바뀜
class MovieLogTextFormField extends StatelessWidget {
  const MovieLogTextFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    required this.status,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.trailing,
    this.action,
    this.forceErrorText,
    this.helperText,
    this.helperColor,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final FieldStatus status;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  /// 상태 아이콘 앞에 붙는 위젯 (ex. 비밀번호 보기 버튼)
  final Widget? trailing;

  /// 입력창 오른쪽에 붙는 위젯 (ex. 중복 확인 버튼)
  final Widget? action;

  /// validator 말고 밖에서 넣는 에러 문구 (서버 결과 등)
  final String? forceErrorText;

  /// 에러 없을 때 보여줄 안내 문구
  final String? helperText;
  final Color? helperColor;

  /// 가입 요청 중엔 false (입력 못 바꾸게)
  final bool enabled;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusIcon = switch (status) {
      FieldStatus.error => const Icon(
        Icons.error_outline,
        color: AppColors.error,
      ),
      FieldStatus.valid => const Icon(
        Icons.check_circle,
        color: AppColors.violet,
      ),
      FieldStatus.idle => null,
    };
    final suffixIcons = [?trailing, ?statusIcon];

    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      forceErrorText: forceErrorText,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: textTheme.titleMedium?.copyWith(color: AppColors.hint),
        errorStyle: textTheme.labelMedium?.copyWith(color: AppColors.error),
        helperText: helperText,
        helperStyle: textTheme.labelMedium?.copyWith(color: helperColor),
        isDense: true,
        filled: true,
        // 에러면 배경색 변경
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.error)
              ? AppColors.errorContainer
              : AppColors.cardBackground,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        suffixIcon: suffixIcons.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: suffixIcons,
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minHeight: 40),
        enabledBorder: _border(AppColors.inputBorder),
        focusedBorder: _border(AppColors.violet),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
      ),
    );
    final button = action;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        if (button == null)
          field
        else
          // 입력창은 Expanded로 남은 너비 채움
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              button,
            ],
          ),
      ],
    );
  }
}
