import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../view_models/submit_status.dart';
import '../movielog_button.dart';

/// 평점 삭제 확인 Dialog
/// - onConfirm 있으면 (단일 삭제): 삭제 끝날 때까지 Dialog 유지 + 로딩
/// - onConfirm 없으면 (다중 삭제): 확인만 받고 바로 닫힘, 삭제는 화면이 이어서 함
/// 취소는 onConfirm 안 부름 → 삭제 요청 없음
class DeleteRatingDialog extends StatefulWidget {
  const DeleteRatingDialog({
    super.key,
    this.title = '평점을 삭제할까요?',
    this.onConfirm,
  });

  final String title;
  final Future<void> Function()? onConfirm;

  /// 삭제까지 마쳤거나(단일) 확인 눌렀을 때(다중)만 true
  static Future<bool?> show(
    BuildContext context, {
    String title = '평점을 삭제할까요?',
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것 막음
      barrierColor: AppColors.barrier,
      builder: (_) => DeleteRatingDialog(title: title, onConfirm: onConfirm),
    );
  }

  @override
  State<DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  Future<void> _onDelete() async {
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패하면 Dialog 그대로 두고 다시 시도 가능
      setState(() {
        _isDeleting = false;
        _errorText = error is SubmitFailure
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // Figma W7-REQ 평점 삭제 확인 기준 (Dialog 328 x 240, 버튼 134 x 44)
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorText = _errorText;

    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 31, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 37),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 19),
              Text(
                '삭제한 평점은 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: AppColors.textSecondary,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 56),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      variant: MovieLogButtonVariant.tonal,
                      borderRadius: 8,
                      fontSize: 14,
                      onPressed: _isDeleting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: MovieLogButton(
                      label: '삭제',
                      borderRadius: 8,
                      fontSize: 14,
                      isLoading: _isDeleting,
                      onPressed: _onDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
