import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import 'provider_types.dart';

/// Everything a provider needs to run one turn.
class ChatRequest {
  const ChatRequest({
    required this.messages,
    required this.model,
    required this.params,
    this.tools = const [],
    this.cancelToken,
  });

  final List<ChatMessage> messages;
  final String model;
  final GenerationParams params;

  /// Normalized tool specs (empty = plain chat).
  final List<ProviderToolSpec> tools;
  final CancelToken? cancelToken;
}

/// Pluggable AI provider interface.
abstract class AIProvider {
  /// Stable id matching the stored ProviderConfigs row.
  String get configId;

  String get displayName;

  bool get supportsTools;
  bool get supportsVision;

  /// Live model list; implementations should throw on auth/network errors
  /// so the settings UI can surface a clear test result.
  Future<List<String>> listModels();

  /// Streams one assistant turn as [ChatStreamEvent]s.
  Stream<ChatStreamEvent> streamMessage(ChatRequest request);
}
