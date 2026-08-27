import 'dart:convert';

import 'package:dio/dio.dart' show CancelToken;
import 'package:uuid/uuid.dart';

import '../../../core/models/chat_models.dart';
import '../../../shared/widgets/confirm_action_sheet.dart';
import '../../providers/domain/ai_provider.dart';
import '../domain/agent_event.dart';
import '../domain/agent_tool.dart';

/// ReAct-style agent loop: think → act → observe → repeat.
///
/// The engine is UI-agnostic: confirmations are requested through the
/// [requestConfirmation] callback and surfaced by the chat layer.
class AgentEngine {
  AgentEngine({this.maxSteps = 50});

  static const _uuid = Uuid();

  /// Safety bound so a runaway model can't loop forever.
  final int maxSteps;

  Stream<AgentEvent> run({
    required AIProvider provider,
    required List<ChatMessage> history,
    required String model,
    required GenerationParams params,
    required List<AgentTool> tools,
    required ConfirmationPolicy policy,
    required Future<ConfirmResult> Function(
      AgentTool tool,
      ToolCallInfo call,
    ) requestConfirmation,

    /// Tool names the user permanently approved ("Always") this session,
    /// plus per-MCP-tool forced confirmations applied by the caller.
    Set<String> sessionApproved = const {},
    Set<String> forceConfirm = const {},
    CancelToken? cancelToken,
  }) async* {
    final messages = List<ChatMessage>.from(history);
    final approved = Set<String>.from(sessionApproved);
    var cancelled = false;

    for (var step = 0; step < maxSteps; step++) {
      if (cancelToken?.isCancelled ?? false) {
        cancelled = true;
        break;
      }

      yield AgentStatusEvent(
        step == 0 ? 'Thinking…' : 'Thinking (step ${step + 1})…',
      );

      final textBuffer = StringBuffer();
      final toolCalls = <ToolCallInfo>[];
      String? streamError;

      await for (final event in provider.streamMessage(ChatRequest(
        messages: messages,
        model: model,
        params: params,
        tools: tools.map((t) => t.toSpec()).toList(),
        cancelToken: cancelToken,
      ))) {
        switch (event) {
          case TextDeltaEvent(:final text):
            textBuffer.write(text);
            yield AgentTextDeltaEvent(text);
          case SpeedMetricsEvent():
            break;
          case ToolCallsEvent(:final calls):
            toolCalls.addAll(calls);
          case UsageEvent(:final usage):
            yield AgentUsageEvent(usage);
          case StreamDoneEvent():
            break;
          case StreamErrorEvent(:final message):
            streamError = message;
        }
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
      }

      if (cancelled) break;

      if (streamError != null) {
        yield AgentRunErrorEvent(streamError);
        break;
      }

      final assistantMessage = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        content: textBuffer.toString(),
        toolCalls: toolCalls,
        createdAt: DateTime.now(),
      );
      messages.add(assistantMessage);

      // No tool calls → final answer.
      if (toolCalls.isEmpty) {
        yield AgentAssistantMessageEvent(assistantMessage);
        break;
      }

      yield AgentStatusEvent('Executing ${toolCalls.length} tool '
          'call${toolCalls.length > 1 ? 's' : ''}…');

      for (final call in toolCalls) {
        if (cancelToken?.isCancelled ?? false) {
          cancelled = true;
          break;
        }

        yield AgentToolCallStartedEvent(call);
        final tool = tools
            .where((t) =>
                t.name == call.name ||
                t.name.endsWith('__${call.name}') ||
                call.name.endsWith('__${t.name}'))
            .firstOrNull;

        String observation;
        var isError = false;

        if (tool == null) {
          observation = 'Error: unknown tool "${call.name}".';
          isError = true;
        } else {
          // --- Confirmation gate ---
          final needsConfirm = !approved.contains(tool.name) &&
              (forceConfirm.contains(tool.name) ||
                  switch (policy) {
                    ConfirmationPolicy.alwaysAsk => true,
                    ConfirmationPolicy.destructiveOnly =>
                      tool.risk != ToolRisk.safe,
                    ConfirmationPolicy.autonomous => false,
                  });

          if (needsConfirm) {
            final decision = await requestConfirmation(tool, call);
            switch (decision) {
              case ConfirmResult.allowAlways:
                approved.add(tool.name);
              case ConfirmResult.allow:
                break;
              case ConfirmResult.deny:
                observation =
                    'The user denied permission to run "${tool.name}". '
                    'Do not retry; explain the limitation instead.';
                isError = true;
                yield AgentToolCallDeniedEvent(call);
                messages.add(ChatMessage(
                  id: _uuid.v4(),
                  role: MessageRole.tool,
                  content: observation,
                  toolCallId: call.id,
                  toolName: call.name,
                  createdAt: DateTime.now(),
                ));
                continue;
            }
          }

          // --- Execute ---
          try {
            final args = _decodeArgs(call.argumentsJson);
            observation = await tool.run(args);
          } catch (e) {
            observation = 'Error running ${tool.name}: $e';
            isError = true;
          }
        }

        yield AgentToolCallCompletedEvent(call, observation, isError);
        messages.add(ChatMessage(
          id: _uuid.v4(),
          role: MessageRole.tool,
          content: observation,
          toolCallId: call.id,
          toolName: call.name,
          createdAt: DateTime.now(),
        ));
      }

      if (cancelled) break;
    }

    // If loop finished and the last message was a tool result (i.e. model hasn't synthesized a conclusion),
    // request a final synthesis step without tools so the agent never finishes silently!
    if (!cancelled && messages.isNotEmpty && messages.last.role == MessageRole.tool) {
      yield const AgentStatusEvent('Summarizing actions…');
      final finalBuffer = StringBuffer();
      try {
        await for (final event in provider.streamMessage(ChatRequest(
          messages: messages,
          model: model,
          params: params,
          tools: const [],
          cancelToken: cancelToken,
        ))) {
          if (event is TextDeltaEvent) {
            finalBuffer.write(event.text);
            yield AgentTextDeltaEvent(event.text);
          }
        }
        if (finalBuffer.isNotEmpty) {
          final summaryMessage = ChatMessage(
            id: _uuid.v4(),
            role: MessageRole.assistant,
            content: finalBuffer.toString(),
            createdAt: DateTime.now(),
          );
          yield AgentAssistantMessageEvent(summaryMessage);
        }
      } catch (_) {}
    }

    yield AgentRunFinishedEvent(cancelled);
  }

  static Map<String, dynamic> _decodeArgs(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

