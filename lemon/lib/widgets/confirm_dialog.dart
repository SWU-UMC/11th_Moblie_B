import 'package:flutter/material.dart';

import '../data/services/rating_api_service.dart';
import 'movielog_button.dart';

/// 평점 Dialog와 같은 모양의 확인 Dialog입니다.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.isLoading = false,
    this.errorText,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final errorText = this.errorText;

    return AlertDialog(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: MovieLogButton(
                    label: '취소',
                    tonal: true,
                    height: 48,
                    borderRadius: 24,
                    width: double.infinity,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MovieLogButton(
                    label: confirmLabel,
                    height: 48,
                    borderRadius: 24,
                    width: double.infinity,
                    isLoading: isLoading,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 평점 한 건 삭제 확인 Dialog입니다.
/// 삭제 요청 중에는 Dialog가 닫히지 않고, 실패하면 Dialog 안에서 안내한 뒤 다시 시도할 수 있습니다.
class DeleteRatingDialog extends StatefulWidget {
  const DeleteRatingDialog({super.key, required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  Future<void> _onConfirm() async {
    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorText = error is RatingWriteFailure
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: ConfirmDialog(
        title: '평점을 삭제할까요?',
        message: '삭제한 평점은 복구할 수 없습니다.',
        confirmLabel: '삭제',
        isLoading: _isDeleting,
        errorText: _errorText,
        // 취소는 onConfirm을 부르지 않으므로 삭제 요청을 보내지 않습니다.
        onCancel: _isDeleting ? null : () => Navigator.pop(context, false),
        onConfirm: _isDeleting ? null : _onConfirm,
      ),
    );
  }
}
