import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../widgets/movielog_button.dart';

/// Figma W8 Splash 글자 스타일 (Manrope)
abstract final class _SplashText {
  static const week = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSecondary,
  );

  /// 26 Bold, 줄 간격 34
  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 34 / 26,
    color: AppColors.textPrimary,
  );

  /// 14 Medium, 줄 간격 24
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 24 / 14,
    color: AppColors.textSecondary,
  );

  static const message = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSecondary,
  );
}

/// W8-01 세션 확인 중 / W8-02 확인 실패·재시도
/// 1주차 시작 화면 레이아웃 재사용, 하단 '시작하기' 자리만 바꿈
/// - onRetry null: 토큰 확인 중 → 인디케이터
/// - onRetry 있음: 확인 실패 → 문구 + 다시 시도
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        // 키보드 떠 있거나 작은 화면이어도 Overflow 안 나게 스크롤 허용
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  // Figma: 좌우 32, 버튼 아래 52
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 52),
                  child: Column(
                    children: [
                      // Figma 세로 위치: 주차 66, 로고 138, 제목 261, 설명 350
                      const SizedBox(height: 66),
                      const Text('FLUTTER 8주차', style: _SplashText.week),
                      const SizedBox(height: 57),
                      SvgPicture.asset(
                        'assets/logos/movielog_logo.svg',
                        width: 84,
                        height: 84,
                        semanticsLabel: 'MovieLog 로고',
                      ),
                      const SizedBox(height: 39),
                      const Text(
                        '영화의 순간을\n기록하세요',
                        textAlign: TextAlign.center,
                        style: _SplashText.title,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                        textAlign: TextAlign.center,
                        style: _SplashText.body,
                      ),
                      const Spacer(),
                      if (retry == null)
                        // 다시 시도 버튼 자리(44) 가운데에 인디케이터
                        const SizedBox(
                          height: 44,
                          child: Center(
                            child: SizedBox.square(
                              dimension: 32,
                              child: CircularProgressIndicator(
                                color: AppColors.violet,
                                strokeWidth: 3,
                                semanticsLabel: '로그인 상태 확인 중',
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          message ?? '로그인 상태를 확인하지 못했어요.',
                          textAlign: TextAlign.center,
                          style: _SplashText.message,
                        ),
                        const SizedBox(height: 27),
                        MovieLogButton(
                          label: '다시 시도',
                          width: double.infinity,
                          fontSize: 14,
                          onPressed: retry,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
