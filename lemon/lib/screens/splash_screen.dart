import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/movielog_button.dart';

/// 앱 시작 시 저장된 토큰을 확인하는 동안 보여주는 화면입니다.
///
/// 1주차 StartScreen의 로고·제목·설명 레이아웃을 그대로 쓰고,
/// 하단 버튼 자리만 상태에 따라 바꿉니다.
/// - [onRetry]가 null: 세션 확인 중(initializing) → 인디케이터
/// - [onRetry]가 있음: 확인 실패(retryRequired) → 안내 문구 + 다시 시도 버튼
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onRetry = this.onRetry;

    return Scaffold(
      body: SafeArea(
        // 화면이 낮거나 글자가 커져도 하단 버튼까지 스크롤해서 닿을 수 있게 합니다.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 32),
                        const Text('FLUTTER 8주차'),
                        const SizedBox(height: 64),
                        SvgPicture.asset(
                          'assets/logos/movielog_logo.svg',
                          width: 72,
                          height: 72,
                          semanticsLabel: 'MovieLog 로고',
                        ),
                        const SizedBox(height: 32),
                        Text(
                          '영화의 순간을\n기록하세요',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    // 1주차 하단 버튼 자리를 로딩/재시도 상태로 대체합니다.
                    if (onRetry == null)
                      Semantics(
                        label: '로그인 상태 확인 중',
                        child: const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Column(
                        children: [
                          const SizedBox(height: 24),
                          Text(
                            message ?? '로그인 상태를 확인하지 못했어요.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MovieLogButton(
                            label: '다시 시도',
                            width: double.infinity,
                            height: 48,
                            onPressed: onRetry,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
