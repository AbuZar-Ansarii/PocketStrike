import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../domain/ai_provider.dart';
import '../domain/provider_types.dart';
import 'sse_parser.dart';

/// Google Gemini client (`streamGenerateContent` over SSE).
class GeminiProvider implements AIProvider {
  GeminiProvider({
    required this.configId,
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
  final String baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  String get displayName => ProviderType.gemini.displayName;

  @override
  bool get supportsTools => true;

  @override
  bool get supportsVision => true;

  Map<String, String> get _headers => {
        if (apiKey != null && apiKey!.isNotEmpty) 'x-goog-api-key': apiKey!,
        'Content-Type': 'application/json',
      };

  @override
  Stream<ChatStreamEvent> streamMessage(ChatRequest request) async* {
    final (system, contents) =
        convertMessages(request.messages, request.params.systemPrompt);
    final body = <String, dynamic>{
      'contents': contents,
      if (system != null)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'generationConfig': {
        'temperature': request.params.temperature,
        'topP': request.params.topP,
        'maxOutputTokens': request.params.maxTokens,
      },
      if (request.tools.isNotEmpty)
        'tools': [
          {'functionDeclarations': convertTools(request.tools)},
        ],
    };

    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '$baseUrl/v1beta/models/${request.model}:streamGenerateContent?alt=sse',
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

    final toolCalls = <ToolCallInfo>[];

    await for (final json in parseSseJsonStream(body1.stream)) {
      final usage = json['usageMetadata'] as Map<String, dynamic>?;
      if (usage != null) {
        yield UsageEvent(UsageInfo(
          promptTokens: (usage['promptTokenCount'] as num?)?.toInt(),
          completionTokens: (usage['candidatesTokenCount'] as num?)?.toInt(),
        ));
      }

      final candidates = json['candidates'];
      if (candidates is! List || candidates.isEmpty) continue;
      final content =
          (candidates.first as Map<String, dynamic>)['content'];
      final parts = (content as Map<String, dynamic>?)?['parts'];
      if (parts is! List) continue;

      for (final raw in parts) {
        final part = raw as Map<String, dynamic>;
        final text = part['text'];
        if (text is String && text.isNotEmpty) {
          yield TextDeltaEvent(text);
        }
        final fnCall = part['functionCall'] as Map<String, dynamic>?;
        if (fnCall != null) {
          toolCalls.add(ToolCallInfo(
            id: 'gemini_${toolCalls.length}_${fnCall['name']}',
            name: fnCall['name'] as String? ?? '',
            argumentsJson: jsonEncode(fnCall['args'] ?? const {}),
          ));
        }
      }
    }

    if (toolCalls.isNotEmpty) yield ToolCallsEvent(toolCalls);
    yield const StreamDoneEvent();
  }

  /// Gemini roles are `user`/`model`; tool results ride in a user turn as
  /// `functionResponse` parts.
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
          break;
        case MessageRole.user:
          out.add({
            'role': 'user',
            'parts': [
              {'text': m.content},
            ],
          });
        case MessageRole.assistant:
          out.add({
            'role': 'model',
            'parts': [
              if (m.content.isNotEmpty) {'text': m.content},
              for (final call in m.toolCalls)
                {
                  'functionCall': {
                    'name': call.name,
                    'args': _tryDecodeJson(call.argumentsJson),
                  },
                },
            ],
          });
        case MessageRole.tool:
          out.add({
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': m.toolName ?? '',
                  'response': {'result': m.content},
                },
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
          'parameters': tool.parameters,
        },
    ];
  }

  @override
  Future<List<String>> listModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/v1beta/models',
        options: Options(headers: _headers),
      );
      final data = response.data?['models'];
      if (data is List) {
        final models = data
            .whereType<Map<String, dynamic>>()
            .map((m) => (m['name'] as String? ?? '')
                .replaceFirst('models/', ''))
            .where((m) => m.isNotEmpty)
            .toList();
        if (models.isNotEmpty) return models;
      }
      return ProviderType.gemini.suggestedModels;
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }
}

