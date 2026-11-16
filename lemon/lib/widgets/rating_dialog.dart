import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

/// 별점(1~5 정수)과 코멘트를 받아 [onSubmit]으로 저장하는 Dialog입니다.
///
/// - 저장이 예외 없이 끝나면 true, 취소하면 onSubmit을 부르지 않고 false를 돌려줍니다.
/// - 저장 중에는 버튼·입력·뒤로 가기를 막습니다. 바깥 탭은 호출부의
///   `barrierDismissible: false`로 막습니다.
/// - 저장에 실패하면 Dialog를 닫지 않고 입력값을 그대로 둔 채 오류를 보여줍니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    this.movieTitle,
    required this.onSubmit,
  });

  /// 0이면 아직 별점을 고르지 않은 상태입니다. (등록)
  /// 수정할 때는 기존 별점을 넣어 Dialog가 열리자마자 보여줍니다.
  final int initialScore;

  /// null이면 코멘트 입력칸이 빈 칸으로 시작합니다.
  final String? initialComment;

  /// 어떤 영화의 평점인지 제목 아래에 보여줍니다. 없으면 표시하지 않습니다.
  final String? movieTitle;

  /// 빈 코멘트는 null로 바꿔 전달합니다.
  final Future<void> Function(int score, String? comment) onSubmit;

  static const maxCommentLength = 500;

  /// 서버는 이모지도 한 글자로 셉니다(코드포인트 기준). 카운터·입력 제한·제출 검사를 모두 이 기준으로 맞춥니다.
  static int commentLength(String text) => text.runes.length;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;
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
    // 버튼이 다시 그려지기 전에 두 번 눌려도 저장은 한 번만 시작합니다.
    if (_isSubmitting) return;
    final trimmed = _commentController.text.trim();
    if (RatingDialog.commentLength(trimmed) > RatingDialog.maxCommentLength) {
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
      setState(() {
        _isSubmitting = false;
        _errorText = error is RatingWriteFailure
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.outlineVariant, width: 1.5),
    );
    final movieTitle = widget.movieTitle;
    final errorText = _errorText;

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '평점을 남겨주세요',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (movieTitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    movieTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                MovieRatingInput(
                  rating: _score.toDouble(),
                  enabled: !_isSubmitting,
                  onChanged: (value) =>
                      setState(() => _score = validateServerScore(value)),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '코멘트 (선택, 최대 500자)',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  enabled: !_isSubmitting,
                  minLines: 3,
                  maxLines: 5,
                  inputFormatters: const [
                    _MaxRunesFormatter(RatingDialog.maxCommentLength),
                  ],
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '이 영화의 인상적인 장면은...',
                    counterText:
                        '${RatingDialog.commentLength(_commentController.text)}'
                        '/${RatingDialog.maxCommentLength}',
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    contentPadding: const EdgeInsets.all(16),
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    disabledBorder: fieldBorder,
                    focusedBorder: fieldBorder.copyWith(
                      borderSide: BorderSide(color: colors.primary, width: 2),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorText,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
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
                        // 취소하면 onSubmit을 부르지 않으므로 API 요청도 없습니다.
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MovieLogButton(
                        label: '확인',
                        height: 48,
                        borderRadius: 24,
                        width: double.infinity,
                        isLoading: _isSubmitting,
                        // 별점을 고르기 전에는 코멘트를 입력해도 누를 수 없습니다.
                        onPressed: _score > 0 && !_isSubmitting
                            ? _onConfirm
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 코드포인트 기준으로 최대 길이를 넘는 입력을 막습니다. (붙여넣기 포함)
class _MaxRunesFormatter extends TextInputFormatter {
  const _MaxRunesFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RatingDialog.commentLength(newValue.text) <= max ? newValue : oldValue;
}
