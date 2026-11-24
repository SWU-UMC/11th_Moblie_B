import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/movielog_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
            ),
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
                      width: 84,
                      height: 84,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '영화의 순간을\n기록하세요',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: onRetry == null
                      ? const CircularProgressIndicator()
                      : Column(
                          children: [
                            Text(message ?? '로그인 상태를 확인하지 못했어요.'),
                            const SizedBox(height: 12),
                            MovieLogButton(
                              label: '다시 시도',
                              width: double.infinity,
                              onPressed: onRetry,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
