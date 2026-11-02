import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart' as app;

void main() {
  testWidgets('Hello MovieLog! 텍스트 하나가 표시된다', (WidgetTester tester) async {
    app.main();
    await tester.pump();

    expect(find.text('Hello MovieLog!'), findsOneWidget);
  });
}
