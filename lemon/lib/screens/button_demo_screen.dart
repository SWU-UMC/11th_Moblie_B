import 'package:flutter/material.dart';

import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';

/// MovieLogButton의 너비 옵션과 상태를 한 화면에서 비교하는 개발용 화면입니다.
/// Debug 빌드에서만 `/dev/buttons` 경로로 열립니다.
class ButtonDemoScreen extends StatelessWidget {
  const ButtonDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: 'MovieLogButton',
        titleColor: colors.primary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _Section(
              title: 'width: null',
              caption: '내용(label) 길이만큼만 차지합니다.',
              children: [
                _Outlined(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MovieLogButton(label: '확인', onPressed: _noop),
                  ),
                ),
                _Outlined(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MovieLogButton(label: '조금 더 긴 라벨', onPressed: _noop),
                  ),
                ),
              ],
            ),
            const _Section(
              title: 'width: 120 (고정 값)',
              caption: 'label 길이와 관계없이 항상 같은 너비입니다.',
              children: [
                _Outlined(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MovieLogButton(
                      label: '확인',
                      width: 120,
                      onPressed: _noop,
                    ),
                  ),
                ),
                _Outlined(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MovieLogButton(
                      label: '조금 더 긴 라벨',
                      width: 120,
                      onPressed: _noop,
                    ),
                  ),
                ),
              ],
            ),
            const _Section(
              title: 'width: double.infinity',
              caption: '부모가 허용하는 최대 너비를 모두 사용합니다.',
              children: [
                _Outlined(
                  child: MovieLogButton(
                    label: '확인',
                    width: double.infinity,
                    onPressed: _noop,
                  ),
                ),
              ],
            ),
            _Section(
              title: '입력창 옆 배치 (width: null)',
              caption: 'Expanded 입력창 + 8px + 내용 기반 버튼',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '닉네임',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MovieLogButton(label: '중복 확인', onPressed: () {}),
                  ],
                ),
              ],
            ),
            const _Section(
              title: '상태',
              caption: '기본 · 통신 중(회색 + 인디케이터) · 비활성(onPressed: null)',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MovieLogButton(label: '중복 확인', onPressed: _noop),
                    MovieLogButton(
                      label: '중복 확인',
                      isLoading: true,
                      onPressed: _noop,
                    ),
                    MovieLogButton(label: '중복 확인', onPressed: null),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.caption,
    required this.children,
  });

  final String title;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            caption,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final child in children) ...[child, const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

/// 부모 영역을 점선 대신 얇은 테두리로 보여줘, 버튼이 차지하는 너비를 비교하기 쉽게 합니다.
class _Outlined extends StatelessWidget {
  const _Outlined({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
