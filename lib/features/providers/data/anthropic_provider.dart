import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';
import 'sse_parser.dart';

/// Anthropic Messages API client (SSE streaming, tool_use blocks).
class AnthropicProvider implements AIProvider {
  AnthropicProvider({
    required this.configId,
    required this.baseUrl,
    this.apiKey,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ));

  static const _apiVersion = '2023-06-01';

  @override
  final String configId;
  final String baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  String get displayName => ProviderType.anthropic.displayName;

  @override
  bool get supportsTools => true;

  @override
  bool get supportsVision => true;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'anthropic-version': _apiVersion,
      'Content-Type': 'application/json',
    };
    final key = apiKey;
    if (key != null && key.isNotEmpty) headers['x-api-key'] = key;
    return headers;
  }

  @override
  Stream<ChatStreamEvent> streamMessage(ChatRequest request) async* {
    final (system, messages) =
        convertMessages(request.messages, request.params.systemPrompt);
    final body = <String, dynamic>{
      'model': request.model,
      'messages': messages,
      'system': ?system,
      'max_tokens': request.params.maxTokens,
      'temperature': request.params.temperature,
      'top_p': request.params.topP,
      'stream': true,
      if (request.tools.isNotEmpty) 'tools': convertTools(request.tools),
    };

    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '$baseUrl/v1/messages',
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
      yield StreamErrorEvent(dioErrorMessage(e));
      return;
    }

    final body1 = response.data;
    if (body1 == null) {
      yield const StreamErrorEvent('Empty response body');
      return;
    }

    // Anthropic streams content blocks; tool_use blocks accumulate JSON input.
    final toolBuilders = <int, _AnthropicToolBlock>{};
    int? inputTokens;
    int? outputTokens;

    await for (final json in parseSseJsonStream(body1.stream)) {
      final type = json['type'] as String?;
      switch (type) {
        case 'message_start':
          final usage =
              (json['message'] as Map<String, dynamic>?)?['usage'];
          if (usage is Map<String, dynamic>) {
            inputTokens = (usage['input_tokens'] as num?)?.toInt();
          }
        case 'content_block_start':
          final block = json['content_block'] as Map<String, dynamic>?;
          if (block?['type'] == 'tool_use') {
            final index = (json['index'] as num?)?.toInt() ?? 0;
            toolBuilders[index] = _AnthropicToolBlock(
              id: block!['id'] as String? ?? 'toolu_$index',
              name: block['name'] as String? ?? '',
            );
          }
        case 'content_block_delta':
          final delta = json['delta'] as Map<String, dynamic>?;
          if (delta == null) break;
          if (delta['type'] == 'text_delta') {
            final text = delta['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield TextDeltaEvent(text);
            }
          } else if (delta['type'] == 'input_json_delta') {
            final index = (json['index'] as num?)?.toInt() ?? 0;
            final partial = delta['partial_json'] as String?;
            if (partial != null) {
              toolBuilders[index]?.jsonInput.write(partial);
            }
          }
        case 'message_delta':
          final usage = json['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            outputTokens = (usage['output_tokens'] as num?)?.toInt();
          }
        case 'message_stop':
          break;
      }
    }

    if (inputTokens != null || outputTokens != null) {
      yield UsageEvent(UsageInfo(
        promptTokens: inputTokens,
        completionTokens: outputTokens,
      ));
    }

    if (toolBuilders.isNotEmpty) {
      final calls = toolBuilders.entries
          .where((e) => e.value.name.isNotEmpty)
          .map((e) => ToolCallInfo(
                id: e.value.id,
                name: e.value.name,
                argumentsJson: e.value.jsonInput.isEmpty
                    ? '{}'
                    : e.value.jsonInput.toString(),
              ))
          .toList();
      if (calls.isNotEmpty) yield ToolCallsEvent(calls);
    }
    yield const StreamDoneEvent();
  }

  /// Anthropic requires `system` as a top-level string; returns the system
  /// prompt and the converted non-system messages separately.
  static (String?, List<Map<String, dynamic>>) convertMessages(
    List<ChatMessage> messages,
    String? extraSystemPrompt,
  ) {
    final systemParts = <String>[
      if (extraSystemPrompt != null && extraSystemPrompt.isNotEmpty)
        extraSystemPrompt,
      for (final m in messages)
        if (m.role == MessageRole.system && m.content.isNotEmpty) m.content,
    ];

    final out = <Map<String, dynamic>>[];
    for (final m in messages) {
      switch (m.role) {
        case MessageRole.system:
          break; // hoisted above
        case MessageRole.user:
          out.add({'role': 'user', 'content': m.content});
        case MessageRole.assistant:
          out.add({
            'role': 'assistant',
            'content': [
              if (m.content.isNotEmpty) {'type': 'text', 'text': m.content},
              for (final call in m.toolCalls)
                {
                  'type': 'tool_use',
                  'id': call.id,
                  'name': call.name,
                  'input': _tryDecodeJson(call.argumentsJson),
                },
            ],
          });
        case MessageRole.tool:
          // Anthropic expects tool results inside a user turn.
          out.add({
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': m.toolCallId,
                'content': m.content,
              },
            ],
          });
      }
    }
    return (systemParts.isEmpty ? null : systemParts.join('\n\n'), out);
  }

  static Object _tryDecodeJson(String json) {
    try {
      return jsonDecode(json);
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static List<Map<String, dynamic>> convertTools(
    List<ProviderToolSpec> tools,
  ) {
    return [
      for (final tool in tools)
        {
          'name': tool.name,
          'description': tool.description,
          'input_schema': tool.parameters,
        },
    ];
  }

  @override
  Future<List<String>> listModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/v1/models',
        options: Options(headers: _headers),
      );
      final data = response.data?['data'];
      if (data is List) {
        final models = data
            .whereType<Map<String, dynamic>>()
            .map((m) => m['id'])
            .whereType<String>()
            .toList();
        if (models.isNotEmpty) return models;
      }
      return ProviderType.anthropic.suggestedModels;
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }
}

class _AnthropicToolBlock {
  _AnthropicToolBlock({required this.id, required this.name});

  final String id;
  final String name;
  final StringBuffer jsonInput = StringBuffer();
}

