import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/app_theme.dart';

void main() => runApp(const MovieLogApp());

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const StartScreen(),
  );
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        // 내용이 화면에 들어가면 버튼을 맨 아래에 두고,
        // 작은 화면이나 큰 글씨로 넘치면 스크롤해서 '시작하기'까지 볼 수 있게 합니다.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 32),
                        const Text('FLUTTER 1주차'),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {}, // 1주차에는 화면 이동을 연결하지 않습니다.
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                        ),
                        child: const Text('시작하기'),
                      ),
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
