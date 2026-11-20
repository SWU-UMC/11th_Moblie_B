import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/rating_request.dart';
import '../../theme/app_colors.dart';
import '../../view_models/submit_status.dart';
import '../movielog_button.dart';
import 'movie_rating_input.dart';

/// 평점 등록·수정 Dialog (별점 + 코멘트)
/// 저장은 onSubmit으로 받아서 Dialog 안에서 실행
/// - 저장 성공 → true, 취소 → false (onSubmit 안 부름 = API 요청 없음)
/// - 저장 실패 → Dialog 그대로, 입력 유지 + 오류 문구
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.onSubmit,
    this.initialScore = 0,
    this.initialComment,
  });

  static const maxCommentLength = 500;

  /// 수정할 때 기존 값 (0이면 별점 선택 전)
  final int initialScore;

  /// null이면 빈 칸으로 시작
  final String? initialComment;

  final Future<void> Function(int score, String? comment) onSubmit;

  /// barrierDismissible false → 저장 중 바깥 탭으로 안 닫힘
  /// 뒤로가기는 Dialog 안 PopScope가 막음 (둘 다 있어야 완전히 막힘)
  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(int score, String? comment) onSubmit,
    int initialScore = 0,
    String? initialComment,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.barrier,
      builder: (_) => RatingDialog(
        onSubmit: onSubmit,
        initialScore: initialScore,
        initialComment: initialComment,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;

  // build 안에서 만들면 setState마다 새로 생겨서 입력이 날아감 → State에서 한 번만
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > RatingDialog.maxCommentLength) {
      setState(() => _errorText = '코멘트는 500자 이하로 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 로딩 꼭 풀기 (안 풀면 버튼이 계속 로딩 모양)
      setState(() {
        _isSubmitting = false;
        _errorText = error is SubmitFailure
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 2),
  );

  // Figma W7-01 기준 (Dialog 340 x 400, 버튼 140 x 46 알약)
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorText = _errorText;
    final hintStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
      color: AppColors.textSecondary,
    );

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(17, 33, 17, 38),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '평점을 남겨주세요',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: MovieRatingInput(
                  rating: _score.toDouble(),
                  enabled: !_isSubmitting,
                  onChanged: (value) =>
                      setState(() => _score = validateServerScore(value)),
                ),
              ),
              const SizedBox(height: 27),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '코멘트 (선택, 최대 500자)',
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 105,
                child: TextField(
                  controller: _commentController,
                  enabled: !_isSubmitting,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  // 글자 수 표시는 Figma에 없어서 숨기고 500자 제한만 둠
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      RatingDialog.maxCommentLength,
                    ),
                  ],
                  style: hintStyle?.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '이 영화의 인상적인 장면은…',
                    hintStyle: hintStyle,
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    contentPadding: const EdgeInsets.fromLTRB(13, 18, 13, 18),
                    enabledBorder: _fieldBorder(AppColors.fieldBorder),
                    focusedBorder: _fieldBorder(AppColors.violet),
                    disabledBorder: _fieldBorder(AppColors.fieldBorder),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    errorText,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 34),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: MovieLogButton(
                        label: '취소',
                        variant: MovieLogButtonVariant.tonal,
                        height: 46,
                        borderRadius: 23,
                        fontSize: 15,
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      // 별점 골라야 활성화 (코멘트만으론 안 됨)
                      child: MovieLogButton(
                        label: '확인',
                        height: 46,
                        borderRadius: 23,
                        fontSize: 15,
                        isLoading: _isSubmitting,
                        onPressed: _score > 0 ? _onConfirm : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
