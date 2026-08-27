import '../../../core/models/chat_models.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';

/// Offline demo provider — no network, no key.
///
/// Streams a canned markdown reply. When tools are available and the user
/// asks about the time or a calculation, it emits a tool call so the agent
/// loop can be exercised without any configured provider.
class MockProvider implements AIProvider {
  const MockProvider();

  static const configIdValue = 'builtin_mock';

  @override
  String get configId => configIdValue;

  @override
  String get displayName => ProviderType.mock.displayName;

  @override
  bool get supportsTools => true;

  @override
  bool get supportsVision => false;

  @override
  Future<List<String>> listModels() async => ProviderType.mock.suggestedModels;

  @override
  Stream<ChatStreamEvent> streamMessage(ChatRequest request) async* {
    final lastUser = request.messages
        .where((m) => m.role == MessageRole.user)
        .map((m) => m.content.toLowerCase())
        .lastOrNull;

    // If the previous turn ran tools, summarize the observations.
    final lastMessage = request.messages.lastOrNull;
    if (lastMessage != null && lastMessage.role == MessageRole.tool) {
      yield* _streamText(
        'Tool ` ${lastMessage.toolName ?? 'unknown'} ` returned:\n\n'
        '```\n${lastMessage.content}\n```\n\n'
        'The agent run is complete. Ask another question to continue.',
      );
      yield const UsageEvent(UsageInfo(promptTokens: 64, completionTokens: 32));
      yield const StreamDoneEvent();
      return;
    }

    if (request.tools.isNotEmpty && lastUser != null) {
      final wantsTime = lastUser.contains('time') || lastUser.contains('date');
      final wantsCalc =
          lastUser.contains('calculate') || lastUser.contains('calc');
      if (wantsTime &&
          request.tools.any((t) => t.name == 'get_current_time')) {
        yield const TextDeltaEvent('Let me check the current time.\n\n');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        yield const ToolCallsEvent([
          ToolCallInfo(
            id: 'mock_call_time',
            name: 'get_current_time',
            argumentsJson: '{}',
          ),
        ]);
        yield const StreamDoneEvent();
        return;
      }
      if (wantsCalc && request.tools.any((t) => t.name == 'calculator')) {
        final expression = _extractExpression(lastUser);
        yield TextDeltaEvent('I\'ll compute `$expression` for you.\n\n');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        yield ToolCallsEvent([
          ToolCallInfo(
            id: 'mock_call_calc',
            name: 'calculator',
            argumentsJson: '{"expression": "$expression"}',
          ),
        ]);
        yield const StreamDoneEvent();
        return;
      }
    }

    yield* _streamText(_cannedReply);
    yield const UsageEvent(UsageInfo(promptTokens: 128, completionTokens: 96));
    yield const StreamDoneEvent();
  }

  static String _extractExpression(String input) {
    final match = RegExp(r'[\d+\-*/(). ^%]+').allMatches(input).firstOrNull;
    final expr = match?.group(0)?.trim();
    return (expr == null || expr.isEmpty) ? '2 + 2' : expr;
  }

  Stream<ChatStreamEvent> _streamText(String text) async* {
    const chunkSize = 6;
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize > text.length) ? text.length : i + chunkSize;
      yield TextDeltaEvent(text.substring(i, end));
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }

  static const _cannedReply = '''
I'm the **PocketStrike demo provider** — running fully offline.

Here's what I can render:

- **Markdown**: *italic*, **bold**, ~~strike~~, [links](https://flutter.dev)
- Lists, quotes, and tables
- Syntax-highlighted code blocks:

```dart
void main() {
  print('Hello from PocketStrike!');
}
```

> Add a real provider in **Settings → AI Providers** to chat with OpenAI,
> Claude, Gemini, Groq, OpenRouter, or Ollama.

💡 **Agent demo:** toggle *Agent mode* on, then ask me to "calculate 42 * 17"
or "what time is it" to see the tool-call loop in action.
''';
}
