import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 아직 입력창은 TODO 상태다
    expect(find.textContaining('TODO 3'), findsOneWidget);
  });
}
