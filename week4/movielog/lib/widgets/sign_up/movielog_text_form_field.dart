import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 입력값 검증 결과에 따라 달라지는 입력창 상태
enum FieldStatus { idle, error, valid }

/// MovieLog 공통 입력창: 라벨 + TextFormField
///
/// 테두리·배경·오른쪽 아이콘이 [status]에 따라 Figma의
/// 입력 전 / 오류 / 입력 완료 모양으로 바뀝니다.
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

  /// 상태 아이콘 앞에 붙일 Widget (예: 비밀번호 표시·숨김 버튼)
  final Widget? trailing;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: textTheme.titleMedium?.copyWith(color: AppColors.hint),
            errorStyle: textTheme.labelMedium?.copyWith(color: AppColors.error),
            isDense: true,
            filled: true,
            // 오류 상태일 때 배경색이 바뀝니다.
            fillColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.error)
                  ? AppColors.errorContainer
                  : AppColors.cardBackground,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 9,
            ),
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
        ),
      ],
    );
  }
}
