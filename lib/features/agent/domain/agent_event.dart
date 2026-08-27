import '../../../core/models/chat_models.dart';

/// One step in an agent run, shown in the terminal-styled timeline and
/// persisted to the AgentRuns table as JSON.
class AgentStep {
  const AgentStep({
    required this.type,
    required this.timestamp,
    this.text,
    this.toolName,
    this.argumentsJson,
    this.result,
    this.isError = false,
  });

  /// thought | toolCall | observation | denied | error | status
  final String type;
  final DateTime timestamp;
  final String? text;
  final String? toolName;
  final String? argumentsJson;
  final String? result;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        if (text != null) 'text': text,
        if (toolName != null) 'toolName': toolName,
        if (argumentsJson != null) 'argumentsJson': argumentsJson,
        if (result != null) 'result': result,
        'isError': isError,
      };

  factory AgentStep.fromJson(Map<String, dynamic> json) => AgentStep(
        type: json['type'] as String,
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                DateTime.now(),
        text: json['text'] as String?,
        toolName: json['toolName'] as String?,
        argumentsJson: json['argumentsJson'] as String?,
        result: json['result'] as String?,
        isError: json['isError'] as bool? ?? false,
      );
}

/// Live events emitted by the agent engine while running.
sealed class AgentEvent {
  const AgentEvent();
}

class AgentStatusEvent extends AgentEvent {
  const AgentStatusEvent(this.status);
  final String status;
}

class AgentTextDeltaEvent extends AgentEvent {
  const AgentTextDeltaEvent(this.text);
  final String text;
}

class AgentToolCallStartedEvent extends AgentEvent {
  const AgentToolCallStartedEvent(this.call);
  final ToolCallInfo call;
}

class AgentToolCallCompletedEvent extends AgentEvent {
  const AgentToolCallCompletedEvent(this.call, this.result, this.isError);
  final ToolCallInfo call;
  final String result;
  final bool isError;
}

class AgentToolCallDeniedEvent extends AgentEvent {
  const AgentToolCallDeniedEvent(this.call);
  final ToolCallInfo call;
}

/// The assistant turn is complete (no more tool calls).
class AgentAssistantMessageEvent extends AgentEvent {
  const AgentAssistantMessageEvent(this.message);
  final ChatMessage message;
}

class AgentUsageEvent extends AgentEvent {
  const AgentUsageEvent(this.usage);
  final UsageInfo usage;
}

class AgentRunErrorEvent extends AgentEvent {
  const AgentRunErrorEvent(this.message);
  final String message;
}

class AgentRunFinishedEvent extends AgentEvent {
  const AgentRunFinishedEvent(this.cancelled);
  final bool cancelled;
}
