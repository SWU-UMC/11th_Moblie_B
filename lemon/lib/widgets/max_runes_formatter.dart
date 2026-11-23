import 'package:flutter/services.dart';

/// 서버처럼 코드포인트(runes) 기준으로 글자 수를 셉니다.
///
/// Flutter `maxLength`는 grapheme(눈에 보이는 글자) 기준이라 `👩‍💻` 같은 조합 이모지를
/// 1자로 세지만, 서버와 화면 검증은 코드포인트 기준(3자)으로 셉니다.
/// 카운터·입력 제한·제출 검사를 모두 이 기준으로 맞춥니다.
int runeLength(String text) => text.runes.length;

/// 코드포인트 기준으로 최대 길이를 넘는 입력을 막습니다. (붙여넣기 포함)
class MaxRunesFormatter extends TextInputFormatter {
  const MaxRunesFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => runeLength(newValue.text) <= max ? newValue : oldValue;
}
