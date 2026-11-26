/// [values]를 [convert]로 바꾸되, 동시에 [concurrency]개까지만 실행합니다.
/// 결과는 입력과 같은 순서입니다. (즐겨찾기 100개여도 TMDB 요청은 한 번에 최대 5개)
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  // 일꾼 하나가 다음 index를 가져가 끝날 때까지 반복합니다.
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, input.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return output.cast<R>();
}
