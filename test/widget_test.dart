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

  testWidgets('메시지를 보내면 사용자 말풍선과 AI 응답이 보인다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(handler: (prompt) async => '응답: $prompt'),
      ),
    );

    await tester.enterText(find.byType(TextField), '안녕');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('안녕'), findsOneWidget);
    expect(find.text('응답: 안녕'), findsOneWidget);
    expect(find.text('무엇이든 물어보세요'), findsNothing);
  });

  testWidgets('500 오류 후 다시 시도로 마지막 메시지를 재전송한다',
      (WidgetTester tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          handler: (prompt) async {
            attempts++;
            if (attempts == 1) throw const ChatException(500);
            return '복구됨: $prompt';
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '테스트');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('500'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump();

    expect(find.text('복구됨: 테스트'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('429 오류는 1초, 2초 간격으로 재시도한다',
      (WidgetTester tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          handler: (prompt) async {
            attempts++;
            if (attempts < 3) throw const ChatException(429);
            return '성공: $prompt';
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '재시도');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();
    expect(attempts, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 2);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(attempts, 3);
    expect(find.text('성공: 재시도'), findsOneWidget);
  });
}
