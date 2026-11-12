import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FE4)),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

typedef ChatHandler = Future<String> Function(String prompt);

/// 401/429/500/timeout을 하나의 오류 상태로 표현한다.
///
/// [statusCode]가 null이면 timeout이다.
class ChatException implements Exception {
  const ChatException(this.statusCode, [this.detail]);

  const ChatException.timeout([this.detail]) : statusCode = null;

  final int? statusCode;
  final String? detail;

  bool get isTimeout => statusCode == null;
  bool get isRateLimit => statusCode == 429;

  @override
  String toString() {
    if (isTimeout) return 'ChatException(timeout)';
    return 'ChatException($statusCode${detail == null ? '' : ', $detail'})';
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.handler});

  /// 테스트나 실제 프록시 연결 시 주입할 수 있다.
  final ChatHandler? handler;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Duration _simulatedLatency = Duration(milliseconds: 900);
  static const Duration _retryBaseDelay = Duration(seconds: 1);

  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;
  ChatException? _error;
  String? _lastFailedText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_sending) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _error = null;
    });
    _requestAi(text);
  }

  void _retry() {
    final text = _lastFailedText;
    if (text == null || _sending) return;
    _requestAi(text);
  }

  Future<void> _requestAi(String prompt) async {
    if (_sending) return;

    setState(() {
      _sending = true;
      _error = null;
      _lastFailedText = prompt;
    });

    try {
      final reply = await _requestWithRetry(prompt);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } on ChatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = const ChatException(500));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<String> _requestWithRetry(String prompt) async {
    var attempt = 0;
    while (true) {
      try {
        return await _fetch(prompt);
      } on ChatException catch (error) {
        if (error.isRateLimit && attempt < 2) {
          await Future<void>.delayed(_retryBaseDelay * (1 << attempt));
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<String> _fetch(String prompt) async {
    final handler = widget.handler;
    if (handler != null) {
      try {
        return await handler(prompt);
      } on TimeoutException catch (error) {
        throw ChatException.timeout(error.message);
      }
    }

    await Future<void>.delayed(_simulatedLatency);

    final normalized = prompt.toLowerCase();
    if (normalized.contains('401')) {
      throw const ChatException(401, 'unauthorized');
    }
    if (normalized.contains('429')) {
      throw const ChatException(429, 'rate limited');
    }
    if (normalized.contains('500')) {
      throw const ChatException(500, 'internal server error');
    }
    if (normalized.contains('timeout')) {
      throw const ChatException.timeout('simulated timeout');
    }

    return '「$prompt」에 대한 답변이에요. '
        '서버가 연결되면 실제 AI 응답으로 바뀝니다.';
  }

  String _errorMessage(ChatException error) {
    if (error.isTimeout) {
      return '응답 시간이 초과됐어요. 다시 시도해 주세요.';
    }
    switch (error.statusCode) {
      case 401:
        return '인증에 실패했어요. (401)';
      case 429:
        return '요청이 너무 많아요. 잠시 후 다시 시도해 주세요. (429)';
      case 500:
        return '서버에 문제가 생겼어요. (500)';
      default:
        return '오류가 발생했어요. (${error.statusCode}) 다시 시도해 주세요.';
    }
  }

  Widget _buildStatus() {
    if (_error != null) {
      return _ErrorBubble(
        key: const ValueKey('error'),
        message: _errorMessage(_error!),
        onRetry: _sending ? null : _retry,
      );
    }
    if (_sending) {
      return const _LoadingBubble(key: ValueKey('loading'));
    }
    return const SizedBox.shrink(key: ValueKey('idle'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('AI Chat — 실습 1')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _messages[_messages.length - 1 - index];
                      return _Bubble(message: message);
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _messages.isEmpty
                            ? const Center(
                                key: ValueKey('empty'),
                                child: Text(
                                  '무엇이든 물어보세요',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('messages'),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildStatus(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    tooltip: '전송',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '답변을 준비하고 있어요',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
