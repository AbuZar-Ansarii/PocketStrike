/// Provider-agnostic chat models shared by the provider layer, the agent
/// engine and persistence.
library;

enum MessageRole { system, user, assistant, tool }

/// A tool invocation requested by the model.
class ToolCallInfo {
  const ToolCallInfo({
    required this.id,
    required this.name,
    required this.argumentsJson,
    this.result,
    this.isError,
  });

  final String id;
  final String name;
  final String argumentsJson;
  final String? result;
  final bool? isError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'argumentsJson': argumentsJson,
        if (result != null) 'result': result,
        if (isError != null) 'isError': isError,
      };

  factory ToolCallInfo.fromJson(Map<String, dynamic> json) => ToolCallInfo(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'tool',
        argumentsJson: (json['argumentsJson'] as String?) ?? '{}',
        result: json['result'] as String?,
        isError: json['isError'] as bool?,
      );
}

/// Metadata for a file/image attached to a message.
class AttachmentMeta {
  const AttachmentMeta({
    required this.name,
    required this.path,
    required this.mimeType,
    this.sizeBytes,
  });

  final String name;
  final String path;
  final String mimeType;
  final int? sizeBytes;

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
      };

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) =>
      AttachmentMeta(
        name: json['name'] as String,
        path: json['path'] as String,
        mimeType: json['mimeType'] as String,
        sizeBytes: json['sizeBytes'] as int?,
      );
}

/// A single message in a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
    this.attachments = const [],
    this.tokensPerSecond,
    this.tokenCount,
    this.createdAt,
  });

  final String id;
  final MessageRole role;
  final String content;

  /// Set on assistant messages when the model requests tool invocations.
  final List<ToolCallInfo> toolCalls;

  /// Set on [MessageRole.tool] messages: which call this result answers.
  final String? toolCallId;
  final String? toolName;
  final List<AttachmentMeta> attachments;
  final double? tokensPerSecond;
  final int? tokenCount;
  final DateTime? createdAt;

  ChatMessage copyWith({
    String? content,
    List<ToolCallInfo>? toolCalls,
    double? tokensPerSecond,
    int? tokenCount,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        toolCalls: toolCalls ?? this.toolCalls,
        toolCallId: toolCallId,
        toolName: toolName,
        attachments: attachments,
        tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
        tokenCount: tokenCount ?? this.tokenCount,
        createdAt: createdAt,
      );
}

/// Token usage reported by a provider.
class UsageInfo {
  const UsageInfo({this.promptTokens, this.completionTokens});

  final int? promptTokens;
  final int? completionTokens;

  int get total => (promptTokens ?? 0) + (completionTokens ?? 0);
}

/// Events emitted by `AIProvider.streamMessage`.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class TextDeltaEvent extends ChatStreamEvent {
  const TextDeltaEvent(this.text);
  final String text;
}

class SpeedMetricsEvent extends ChatStreamEvent {
  const SpeedMetricsEvent({
    required this.tokensPerSecond,
    this.tokenCount,
    this.latencyMs,
  });
  final double tokensPerSecond;
  final int? tokenCount;
  final int? latencyMs;
}

/// Full set of tool calls requested by the model for this turn.
class ToolCallsEvent extends ChatStreamEvent {
  const ToolCallsEvent(this.calls);
  final List<ToolCallInfo> calls;
}

class UsageEvent extends ChatStreamEvent {
  const UsageEvent(this.usage);
  final UsageInfo usage;
}

class StreamDoneEvent extends ChatStreamEvent {
  const StreamDoneEvent();
}

class StreamErrorEvent extends ChatStreamEvent {
  const StreamErrorEvent(this.message);
  final String message;
}

/// Generation parameters (per-provider sane defaults live in the
/// provider registry; users can tune them in Settings).
class GenerationParams {
  const GenerationParams({
    this.temperature = 0.7,
    this.topP = 1.0,
    this.maxTokens = 4096,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.systemPrompt,
  });

  final double temperature;
  final double topP;
  final int maxTokens;
  final double frequencyPenalty;
  final double presencePenalty;
  final String? systemPrompt;

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'frequencyPenalty': frequencyPenalty,
        'presencePenalty': presencePenalty,
        'systemPrompt': systemPrompt,
      };

  factory GenerationParams.fromJson(Map<String, dynamic> json) =>
      GenerationParams(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4096,
        frequencyPenalty:
            (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        presencePenalty:
            (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        systemPrompt: json['systemPrompt'] as String?,
      );

  GenerationParams copyWith({
    double? temperature,
    double? topP,
    int? maxTokens,
    double? frequencyPenalty,
    double? presencePenalty,
    String? systemPrompt,
  }) =>
      GenerationParams(
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        maxTokens: maxTokens ?? this.maxTokens,
        frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
        presencePenalty: presencePenalty ?? this.presencePenalty,
        systemPrompt: systemPrompt ?? this.systemPrompt,
      );
}
