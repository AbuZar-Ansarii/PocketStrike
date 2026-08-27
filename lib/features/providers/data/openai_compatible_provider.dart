import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';
import 'openai_streaming.dart';
import 'sse_parser.dart';

/// OpenAI-compatible chat-completions client.
///
/// Also powers Groq, OpenRouter, Ollama (`/v1`) and user-defined custom
/// endpoints — they all share this wire format.
class OpenAiCompatibleProvider implements AIProvider {
  OpenAiCompatibleProvider({
    required this.configId,
    required this.type,
    required this.baseUrl,
    this.apiKey,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ));

  @override
  final String configId;
  final ProviderType type;
  final String baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  String get displayName => type.displayName;

  @override
  bool get supportsTools => true;

  @override
  bool get supportsVision => type != ProviderType.ollama;

  String get _cleanBaseUrl => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  String get _chatCompletionsUrl {
    final clean = _cleanBaseUrl;
    if (clean.endsWith('/chat/completions')) return clean;
    return '$clean/chat/completions';
  }

  String get _modelsUrl {
    final clean = _cleanBaseUrl;
    if (clean.endsWith('/chat/completions')) {
      return clean.replaceAll('/chat/completions', '/models');
    }
    if (clean.endsWith('/models')) return clean;
    return '$clean/models';
  }

  Map<String, String> get _headers => {
        if (apiKey != null && apiKey!.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiKey!.trim()}',
        'Content-Type': 'application/json',
      };

  /// Converts internal messages into OpenAI wire format.
  static List<Map<String, dynamic>> convertMessages(
    List<ChatMessage> messages,
  ) {
    return messages.map((m) {
      switch (m.role) {
        case MessageRole.system:
          return {'role': 'system', 'content': m.content};
        case MessageRole.user:
          return {'role': 'user', 'content': m.content};
        case MessageRole.assistant:
          return {
            'role': 'assistant',
            'content': m.content.isEmpty ? null : m.content,
            if (m.toolCalls.isNotEmpty)
              'tool_calls': [
                for (final call in m.toolCalls)
                  {
                    'id': call.id,
                    'type': 'function',
                    'function': {
                      'name': call.name,
                      'arguments': call.argumentsJson,
                    },
                  },
              ],
          };
        case MessageRole.tool:
          return {
            'role': 'tool',
            'tool_call_id': m.toolCallId,
            if (m.toolName != null) 'name': m.toolName,
            'content': m.content,
          };
      }
    }).toList();
  }

  /// OpenAI function-calling tool schema.
  static List<Map<String, dynamic>> convertTools(
    List<ProviderToolSpec> tools,
  ) {
    return [
      for (final tool in tools)
        {
          'type': 'function',
          'function': {
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.parameters,
          },
        },
    ];
  }

  @override
  Stream<ChatStreamEvent> streamMessage(ChatRequest request) async* {
    final body = <String, dynamic>{
      'model': request.model,
      'messages': convertMessages(request.messages),
      'stream': true,
      'temperature': request.params.temperature,
      'top_p': request.params.topP,
      'max_tokens': request.params.maxTokens,
      if (type == ProviderType.openai) ...{
        'stream_options': {'include_usage': true},
      },
      if (type.supportsPenalties) ...{
        'frequency_penalty': request.params.frequencyPenalty,
        'presence_penalty': request.params.presencePenalty,
      },
      if (request.tools.isNotEmpty) ...{
        'tools': convertTools(request.tools),
        'tool_choice': 'auto',
      },
    };

    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        _chatCompletionsUrl,
        data: jsonEncode(body),
        options: Options(
          headers: _headers,
          responseType: ResponseType.stream,
        ),
        cancelToken: request.cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        yield const StreamDoneEvent();
        return;
      }
      final msg = await readDioErrorMessage(e);
      yield StreamErrorEvent(msg);
      return;
    }

    final body1 = response.data;
    if (body1 == null) {
      yield const StreamErrorEvent('Empty response body');
      return;
    }

    // Accumulate streamed tool-call fragments keyed by their `index`.
    final toolBuilders = <int, ToolCallFragmentBuilder>{};
    String? finishReason;

    await for (final json in parseSseJsonStream(body1.stream)) {
      final usage = json['usage'];
      if (usage is Map<String, dynamic>) {
        yield UsageEvent(UsageInfo(
          promptTokens: (usage['prompt_tokens'] as num?)?.toInt(),
          completionTokens: (usage['completion_tokens'] as num?)?.toInt(),
        ));
      }

      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choice = choices.first as Map<String, dynamic>;
      finishReason = choice['finish_reason'] as String? ?? finishReason;

      final delta = choice['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        yield TextDeltaEvent(content);
      }

      final toolCalls = delta['tool_calls'];
      if (toolCalls is List) {
        for (final raw in toolCalls) {
          final call = raw as Map<String, dynamic>;
          final index = (call['index'] as num?)?.toInt() ?? 0;
          final builder =
              toolBuilders.putIfAbsent(index, ToolCallFragmentBuilder.new);
          builder.absorb(call);
        }
      }
    }

    if (toolBuilders.isNotEmpty || finishReason == 'tool_calls') {
      final calls = toolBuilders.entries
          .map((e) => e.value.build(e.key))
          .whereType<ToolCallInfo>()
          .toList();
      if (calls.isNotEmpty) yield ToolCallsEvent(calls);
    }
    yield const StreamDoneEvent();
  }

  @override
  Future<List<String>> listModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _modelsUrl,
        options: Options(headers: _headers),
      );
      final data = response.data?['data'];
      if (data is List) {
        final models = data
            .whereType<Map<String, dynamic>>()
            .map((m) => m['id'])
            .whereType<String>()
            .toList()
          ..sort();
        if (models.isNotEmpty) return models;
      }
      return type.suggestedModels;
    } on DioException catch (e) {
      throw Exception(await readDioErrorMessage(e));
    }
  }
}
