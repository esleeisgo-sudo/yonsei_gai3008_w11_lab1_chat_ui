import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('빈 상태와 입력창이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    expect(find.text('AI Chat — 실습 1'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('전송'), findsOneWidget);
  });

  testWidgets('메시지를 보내면 말풍선이 추가되고 빈 상태가 사라진다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '안녕');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();

    expect(find.text('안녕'), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsNothing);
  });
}
