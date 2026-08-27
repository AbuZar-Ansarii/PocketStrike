import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/theme_controller.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/core/models/chat_models.dart';
import 'package:pocketstrike/features/agent/data/agent_engine.dart';
import 'package:pocketstrike/features/agent/data/hermes_memory_store.dart';
import 'package:pocketstrike/features/agent/domain/agent_event.dart';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/local_models/data/local_model_engine.dart';
import 'package:pocketstrike/features/local_models/data/local_model_info.dart';
import 'package:pocketstrike/features/local_models/data/local_model_store.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';
import 'package:pocketstrike/features/providers/data/mock_provider.dart';
import 'package:pocketstrike/features/providers/domain/ai_provider.dart';
import 'package:pocketstrike/features/providers/domain/provider_types.dart';
import 'package:pocketstrike/shared/widgets/confirm_action_sheet.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum ChatMode { chat, agent, local }

typedef ConfirmHandler = Future<ConfirmResult> Function(
  AgentTool tool,
  ToolCallInfo call,
);

class ChatState {
  const ChatState({
    this.isGenerating = false,
    this.isGeneratingImage = false,
    this.imageGenerationPrompt,
    this.streamingText = '',
    this.agentMode = false,
    this.localMode = false,
    this.demoMode = false,
    this.tokensPerSecond,
    this.tokenCount,
    this.messageSpeeds = const {},
    this.status,
    this.error,
    this.runId,
    this.steps = const [],
  });

  final bool isGenerating;
  final bool isGeneratingImage;
  final String? imageGenerationPrompt;
  final String streamingText;

  /// ReAct agent mode (runs tool loop) vs plain completion.
  final bool agentMode;

  /// 100% Offline Local on-device GGUF / Image inference mode.
  final bool localMode;

  /// Demo mode uses [MockProvider] for offline testing without API keys.
  final bool demoMode;

  /// Live token generation speed in tokens per second.
  final double? tokensPerSecond;
  final int? tokenCount;

  /// Historical speed per message id.
  final Map<String, double> messageSpeeds;

  final String? status;
  final String? error;
  final String? runId;
  final List<AgentStep> steps;

  ChatMode get currentMode {
    if (localMode) return ChatMode.local;
    if (agentMode) return ChatMode.agent;
    return ChatMode.chat;
  }

  ChatState copyWith({
    bool? isGenerating,
    bool? isGeneratingImage,
    String? imageGenerationPrompt,
    bool clearImagePrompt = false,
    String? streamingText,
    bool? agentMode,
    bool? localMode,
    bool? demoMode,
    double? tokensPerSecond,
    bool clearTokensPerSecond = false,
    int? tokenCount,
    Map<String, double>? messageSpeeds,
    String? status,
    bool clearStatus = false,
    String? error,
    bool clearError = false,
    String? runId,
    List<AgentStep>? steps,
  }) {
    return ChatState(
      isGenerating: isGenerating ?? this.isGenerating,
      isGeneratingImage: isGeneratingImage ?? this.isGeneratingImage,
      imageGenerationPrompt: clearImagePrompt
          ? null
          : (imageGenerationPrompt ?? this.imageGenerationPrompt),
      streamingText: streamingText ?? this.streamingText,
      agentMode: agentMode ?? this.agentMode,
      localMode: localMode ?? this.localMode,
      demoMode: demoMode ?? this.demoMode,
      tokensPerSecond: clearTokensPerSecond
          ? null
          : (tokensPerSecond ?? this.tokensPerSecond),
      tokenCount: tokenCount ?? this.tokenCount,
      messageSpeeds: messageSpeeds ?? this.messageSpeeds,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
      runId: runId ?? this.runId,
      steps: steps ?? this.steps,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this.ref) : super(const ChatState());

  final Ref ref;

  /// Hook supplied by UI to present confirmation dialogs for destructive tools.
  ConfirmHandler? confirmHandler;

  CancelToken? _cancelToken;
  final Set<String> _sessionApprovedTools = {};

  void toggleAgentMode(bool enabled) {
    state = state.copyWith(agentMode: enabled, localMode: false);
  }

  void toggleLocalMode(bool enabled) {
    state = state.copyWith(localMode: enabled, agentMode: false);
  }

  void setChatMode(ChatMode mode) {
    switch (mode) {
      case ChatMode.chat:
        state = state.copyWith(agentMode: false, localMode: false);
      case ChatMode.agent:
        state = state.copyWith(agentMode: true, localMode: false);
      case ChatMode.local:
        state = state.copyWith(agentMode: false, localMode: true);
    }
  }

  void setDemoMode(bool enabled) {
    state = state.copyWith(demoMode: enabled);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> sendMessage({
    required String text,
    List<AttachmentMeta> attachments = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;
    if (state.isGenerating) return;

    // 1. Ensure active conversation exists.
    final conversationId = await ref
        .read(conversationActionsProvider)
        .ensureActiveConversation();

    // 2. Resolve AI provider & model.
    AIProvider provider;
    String model;
    GenerationParams params;

    final lowerTrimmed = trimmed.toLowerCase();
    final isSlashImageCommand = lowerTrimmed.startsWith('/image') ||
        lowerTrimmed.startsWith('/img');
    final isNaturalImageCommand = lowerTrimmed.startsWith('generate image') ||
        lowerTrimmed.startsWith('generate an image') ||
        lowerTrimmed.startsWith('create image') ||
        lowerTrimmed.startsWith('create an image') ||
        lowerTrimmed.startsWith('draw ') ||
        lowerTrimmed.startsWith('paint ') ||
        lowerTrimmed.startsWith('image of');

    // In Agent Mode, natural language requests ("generate an image of...") are executed by the Agent using the generate_image tool.
    // In Plain Mode, both slash and natural language commands trigger direct synthesis.
    final isExplicitImage = state.agentMode
        ? isSlashImageCommand
        : (isSlashImageCommand || isNaturalImageCommand);

    if (state.localMode || isExplicitImage) {
      final localStore = ref.read(localModelStoreProvider);
      final activeLocal = localStore.activeModel;
      provider = LocalAIProvider(activeModel: activeLocal);
      model = activeLocal?.name ?? 'local-gguf-default';
      params = GenerationParams(
        temperature: 0.7,
        maxTokens: activeLocal?.contextSize ?? 2048,
      );
    } else if (state.demoMode) {
      provider = const MockProvider();
      model = 'mock-v1';
      params = const GenerationParams();
    } else {
      final activeConfig = await ref.read(activeProviderConfigProvider.future);
      if (activeConfig == null) {
        state = state.copyWith(
          error: 'No active AI provider configured. Add one in Settings or switch to Local mode.',
        );
        return;
      }
      final resolved = await ref
          .read(providerResolverProvider)
          .resolve(configId: activeConfig.id);
      if (resolved == null) {
        state = state.copyWith(error: 'Failed to initialize AI provider.');
        return;
      }
      provider = resolved;
      model = activeConfig.defaultModel;
      if (model.isEmpty) {
        model = ProviderTypeX.fromId(activeConfig.type).suggestedModels.first;
      }
      params = await ref
          .read(providerResolverProvider)
          .paramsFor(provider.configId);
    }

    // 3. Persist the user message.
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: trimmed,
      attachments: attachments,
      createdAt: DateTime.now(),
    );
    await _persistMessage(conversationId, userMessage);
    await _maybeAutoTitle(conversationId, trimmed);

    // 4. Build provider history (system prompt from persona + prior msgs).
    final history = await _buildHistory(conversationId, params);

    final localStore = ref.read(localModelStoreProvider);
    final isImageRequest = (state.localMode && localStore.activeModel?.type == LocalModelType.imageModel) || isExplicitImage;

    state = state.copyWith(
      isGenerating: true,
      isGeneratingImage: isImageRequest,
      imageGenerationPrompt: isImageRequest ? trimmed : null,
      streamingText: '',
      status: isImageRequest ? 'Generating image…' : 'Thinking…',
      steps: const [],
      clearError: true,
    );
    _cancelToken = CancelToken();

    try {
      if (state.agentMode) {
        await _runAgent(
          conversationId: conversationId,
          provider: provider,
          model: model,
          params: params,
          history: history,
        );
      } else {
        await _runPlainChat(
          conversationId: conversationId,
          provider: provider,
          model: model,
          params: params,
          history: history,
        );
      }
    } finally {
      state = state.copyWith(
        isGenerating: false,
        isGeneratingImage: false,
        clearImagePrompt: true,
        streamingText: '',
        clearStatus: true,
      );
      _cancelToken = null;
    }
  }

  /// Cancels in-flight generation or agent execution.
  void stopGeneration() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User stopped generation');
      state = state.copyWith(
        isGenerating: false,
        isGeneratingImage: false,
        clearImagePrompt: true,
        clearStatus: true,
      );
      _cancelToken = null;
    }
  }

  /// Injects a scheduled reminder message into the active chat.
  Future<void> injectReminderMessage(String title, String content) async {
    final conversationId = await ref
        .read(conversationActionsProvider)
        .ensureActiveConversation();

    final reminderMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: '⏰ **Reminder Alert: $title**\n\n$content',
      createdAt: DateTime.now(),
    );
    await _persistMessage(conversationId, reminderMessage);
  }

  void stop() => stopGeneration();

  /// Re-runs the last user message (regenerate).
  Future<void> regenerate() async {
    final conversationId = ref.read(currentConversationIdProvider);
    if (conversationId == null || state.isGenerating) return;
    final messages = await ref
        .read(appDatabaseProvider)
        .messagesDao
        .getForConversation(conversationId);
    final lastUser = messages.where((m) => m.role == 'user').lastOrNull;
    if (lastUser == null) return;
    // Drop the last exchange, then resend the same prompt.
    await ref
        .read(appDatabaseProvider)
        .messagesDao
        .deleteFrom(conversationId, lastUser.createdAt);
    await sendMessage(text: lastUser.content);
  }

  /// Edits a past user message and re-runs from that point.
  Future<void> editAndResend(Message message, String newText) async {
    if (state.isGenerating) return;
    await ref.read(appDatabaseProvider).messagesDao.deleteFrom(
          message.conversationId,
          message.createdAt,
        );
    await sendMessage(text: newText);
  }

  // ------------------------------------------------------------------
  // Plain streaming chat
  // ------------------------------------------------------------------

  Future<void> _runPlainChat({
    required String conversationId,
    required AIProvider provider,
    required String model,
    required GenerationParams params,
    required List<ChatMessage> history,
  }) async {
    final buffer = StringBuffer();
    UsageInfo? usageInfo;
    String? error;
    final stopwatch = Stopwatch()..start();
    var tokenCount = 0;
    double? lastTps;

    await for (final event in provider.streamMessage(ChatRequest(
      messages: history,
      model: model,
      params: params,
      cancelToken: _cancelToken,
    ))) {
      switch (event) {
        case TextDeltaEvent(:final text):
          buffer.write(text);
          tokenCount += (text.length > 4 ? (text.length / 3.8).ceil() : 1);
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.12) {
            lastTps = tokenCount / elapsed;
          }
          state = state.copyWith(
            streamingText: buffer.toString(),
            tokensPerSecond: lastTps,
            tokenCount: tokenCount,
          );
          break;
        case SpeedMetricsEvent(:final tokensPerSecond, :final tokenCount):
          lastTps = tokensPerSecond;
          state = state.copyWith(
            tokensPerSecond: tokensPerSecond,
            tokenCount: tokenCount ?? state.tokenCount,
          );
          break;
        case UsageEvent(:final usage):
          usageInfo = usage;
          break;
        case StreamErrorEvent(:final message):
          error = message;
          break;
        case ToolCallsEvent():
          break;
        case StreamDoneEvent():
          break;
      }
      if (_cancelToken?.isCancelled ?? false) break;
    }

    stopwatch.stop();
    final totalElapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
    final finalTps = (totalElapsedSec > 0.15 && tokenCount > 0)
        ? (tokenCount / totalElapsedSec)
        : (lastTps ?? state.tokensPerSecond);

    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }

    if (buffer.isNotEmpty) {
      final msgId = _uuid.v4();
      if (finalTps != null && finalTps > 0) {
        state = state.copyWith(
          messageSpeeds: {...state.messageSpeeds, msgId: finalTps},
        );
      }
      await _persistMessage(
        conversationId,
        ChatMessage(
          id: msgId,
          role: MessageRole.assistant,
          content: buffer.toString(),
          tokensPerSecond: finalTps,
          tokenCount: tokenCount > 0 ? tokenCount : null,
          createdAt: DateTime.now(),
        ),
        promptTokens: usageInfo?.promptTokens,
        completionTokens: usageInfo?.completionTokens ??
            (tokenCount > 0 ? tokenCount : null),
      );
    }
  }

  // ------------------------------------------------------------------
  // Agent mode (ReAct loop with tool calling)
  // ------------------------------------------------------------------

  Future<void> _runAgent({
    required String conversationId,
    required AIProvider provider,
    required String model,
    required GenerationParams params,
    required List<ChatMessage> history,
  }) async {
    final tools = await _availableTools(conversationId);
    final forceConfirm = await _forcedMcpConfirmations(conversationId);

    final runId = _uuid.v4();
    await ref.read(appDatabaseProvider).agentRunsDao.upsert(
          AgentRunsCompanion.insert(
            id: runId,
            conversationId: conversationId,
            createdAt: DateTime.now(),
          ),
        );
    state = state.copyWith(runId: runId);

    final engine = AgentEngine();
    final steps = <AgentStep>[];
    final buffer = StringBuffer();
    ChatMessage? finalAssistant;
    var runStatus = 'done';
    final stopwatch = Stopwatch()..start();
    var tokenCount = 0;
    double? lastTps;

    await for (final event in engine.run(
      provider: provider,
      history: history,
      model: model,
      params: params,
      tools: tools,
      policy: _policy,
      sessionApproved: _sessionApprovedTools,
      forceConfirm: forceConfirm,
      cancelToken: _cancelToken,
      requestConfirmation: (tool, call) async {
        final handler = confirmHandler;
        if (handler == null) return ConfirmResult.deny;
        final result = await handler(tool, call);
        if (result == ConfirmResult.allowAlways) {
          _sessionApprovedTools.add(tool.name);
        }
        return result;
      },
    )) {
      switch (event) {
        case AgentStatusEvent(:final status):
          state = state.copyWith(status: status);
          break;
        case AgentTextDeltaEvent(:final text):
          buffer.write(text);
          tokenCount += (text.length > 4 ? (text.length / 3.8).ceil() : 1);
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.12) {
            lastTps = tokenCount / elapsed;
          }
          state = state.copyWith(
            streamingText: buffer.toString(),
            tokensPerSecond: lastTps,
            tokenCount: tokenCount,
          );
          break;
        case AgentToolCallStartedEvent(:final call):
          steps.add(AgentStep(
            type: 'toolCall',
            timestamp: DateTime.now(),
            toolName: call.name,
            argumentsJson: call.argumentsJson,
          ));
          state = state.copyWith(
            steps: List.unmodifiable(steps),
            status: 'Running ${call.name}…',
          );
          break;
        case AgentToolCallCompletedEvent(:final call, :final result, :final isError):
          steps.add(AgentStep(
            type: 'observation',
            timestamp: DateTime.now(),
            toolName: call.name,
            result: result,
            isError: isError,
          ));
          state = state.copyWith(
            steps: List.unmodifiable(steps),
            status: 'Reasoning…',
          );
          await _persistMessage(
            conversationId,
            ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.tool,
              content: result,
              toolCallId: call.id,
              toolName: call.name,
              createdAt: DateTime.now(),
            ),
          );
          break;
        case AgentToolCallDeniedEvent(:final call):
          steps.add(AgentStep(
            type: 'denied',
            timestamp: DateTime.now(),
            toolName: call.name,
          ));
          state = state.copyWith(
            steps: List.unmodifiable(steps),
            status: 'Denied ${call.name}',
          );
          break;
        case AgentAssistantMessageEvent(:final message):
          finalAssistant = message;
          break;
        case AgentUsageEvent():
          break;
        case AgentRunErrorEvent(:final message):
          runStatus = 'error';
          state = state.copyWith(error: message);
          break;
        case AgentRunFinishedEvent(:final cancelled):
          if (cancelled) runStatus = 'cancelled';
          break;
      }
    }

    stopwatch.stop();
    final totalElapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
    final finalTps = (totalElapsedSec > 0.15 && tokenCount > 0)
        ? (tokenCount / totalElapsedSec)
        : (lastTps ?? state.tokensPerSecond);

    final finalText = buffer.toString().trim();
    String contentToPersist = finalText.isNotEmpty
        ? finalText
        : (finalAssistant != null && finalAssistant.content.trim().isNotEmpty
            ? finalAssistant.content.trim()
            : (steps.isNotEmpty
                ? '✅ Finished executing ${steps.where((s) => s.type == 'observation').length} actions.'
                : 'Task completed.'));

    // If the agent generated images, format cleanly with a single verified image card and heading
    final imageGenSteps = steps
        .where((s) => s.type == 'observation' && s.toolName == 'generate_image')
        .toList();

    if (imageGenSteps.isNotEmpty) {
      final verifiedImageTags = <String>[];
      for (final step in imageGenSteps) {
        if (step.result != null && step.result!.contains('![Generated Image](')) {
          final matches = RegExp(r'!\[Generated Image\]\([^)]+\)')
              .allMatches(step.result!);
          for (final m in matches) {
            final tag = m.group(0);
            if (tag != null && !verifiedImageTags.contains(tag)) {
              verifiedImageTags.add(tag);
            }
          }
        }
      }

      // Strip any hallucinated/dummy markdown image tags from the LLM's raw text
      var cleaned = finalText
          .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
          .replaceAll(
            RegExp(
              r'(?:\b(?:Saved|Stored|File|Image|Picture|Path|Location)\s*(?:at|to|path|location)?\s*[:\-]?\s*)?'
              r'(?:file://)?(?:/data/user/\d+/[^\s\)]+|/data/data/[^\s\)]+|/storage/emulated/\d+/[^\s\)]+|app_flutter/[^\s\)]+)(?![^\[]*\]|\))',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      final textLower = cleaned.toLowerCase();
      final isGeneric = cleaned.isEmpty ||
          textLower.startsWith('i have generated') ||
          textLower.startsWith('i\'ve generated') ||
          textLower.startsWith('here is the image') ||
          textLower.startsWith('here is your image') ||
          textLower.startsWith('here\'s the image') ||
          textLower.startsWith('here\'s your image') ||
          textLower.startsWith('image generated') ||
          textLower.startsWith('task completed') ||
          textLower.startsWith('✅ finished executing');

      if (isGeneric && verifiedImageTags.isNotEmpty) {
        contentToPersist = 'Here is your image:\n\n${verifiedImageTags.join('\n\n')}';
      } else if (verifiedImageTags.isNotEmpty) {
        contentToPersist = '$cleaned\n\n${verifiedImageTags.join('\n\n')}';
      }
    }

    final msgId = finalAssistant?.id ?? _uuid.v4();
    if (finalTps != null && finalTps > 0) {
      state = state.copyWith(
        messageSpeeds: {...state.messageSpeeds, msgId: finalTps},
      );
    }

    final toolCallsForMessage = <ToolCallInfo>[];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.type == 'toolCall') {
        AgentStep? observation;
        for (int j = i + 1; j < steps.length; j++) {
          if (steps[j].type == 'observation' &&
              steps[j].toolName == step.toolName) {
            observation = steps[j];
            break;
          }
        }
        toolCallsForMessage.add(
          ToolCallInfo(
            id: step.timestamp.toIso8601String(),
            name: step.toolName ?? 'tool',
            argumentsJson: step.argumentsJson ?? '{}',
            result: observation?.result,
            isError: observation?.isError ?? false,
          ),
        );
      }
    }

    await _persistMessage(
      conversationId,
      ChatMessage(
        id: msgId,
        role: MessageRole.assistant,
        content: contentToPersist,
        toolCalls: toolCallsForMessage,
        tokensPerSecond: finalTps,
        tokenCount: tokenCount > 0 ? tokenCount : null,
        createdAt: DateTime.now(),
      ),
      completionTokens: tokenCount > 0 ? tokenCount : null,
    );

    state = state.copyWith(steps: List.unmodifiable(steps));
    await ref.read(appDatabaseProvider).agentRunsDao.updateRun(
          runId,
          runStatus,
          jsonEncode(steps.map((s) => s.toJson()).toList()),
        );
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<List<AgentTool>> _availableTools(String conversationId) async {
    return ref.read(providerResolverProvider).availableTools(conversationId);
  }

  Future<Set<String>> _forcedMcpConfirmations(
      String conversationId) async {
    return ref
        .read(providerResolverProvider)
        .forcedMcpConfirmations(conversationId);
  }

  ConfirmationPolicy get _policy {
    return ref.read(themeModeProvider).isDark
        ? ConfirmationPolicy.destructiveOnly
        : ConfirmationPolicy.autonomous;
  }

  Future<List<ChatMessage>> _buildHistory(
    String conversationId,
    GenerationParams params,
  ) async {
    final rawMsgs = await ref
        .read(appDatabaseProvider)
        .messagesDao
        .getForConversation(conversationId);

    final chatMsgs = rawMsgs.map((m) {
      List<AttachmentMeta>? atts;
      if (m.attachmentsJson != null) {
        try {
          atts = [
            for (final raw in jsonDecode(m.attachmentsJson!) as List)
              AttachmentMeta.fromJson(raw as Map<String, dynamic>),
          ];
        } catch (_) {}
      }
      List<ToolCallInfo>? toolCalls;
      if (m.toolCallsJson != null) {
        try {
          toolCalls = [
            for (final raw in jsonDecode(m.toolCallsJson!) as List)
              ToolCallInfo.fromJson(raw as Map<String, dynamic>),
          ];
        } catch (_) {}
      }
      return ChatMessage(
        id: m.id,
        role: MessageRole.values.where((r) => r.name == m.role).firstOrNull ?? MessageRole.user,
        content: m.content,
        toolCallId: m.toolCallId,
        toolName: m.toolName,
        toolCalls: toolCalls ?? const [],
        attachments: atts ?? const [],
        createdAt: m.createdAt,
      );
    }).toList();

    final persona = await ref.read(activePersonaProvider.future);
    String systemPrompt = params.systemPrompt ?? '';

    if (persona != null && persona.systemPrompt.trim().isNotEmpty) {
      final pPrompt = persona.systemPrompt;
      systemPrompt = systemPrompt.isEmpty
          ? pPrompt
          : '$systemPrompt\n\n$pPrompt';
    }

    if (!state.localMode) {
      final hermesContext = ref.read(hermesMemoryProvider.notifier).buildHermesSystemPrompt();
      systemPrompt = systemPrompt.isEmpty
          ? hermesContext
          : '$systemPrompt\n\n$hermesContext';
    } else if (systemPrompt.isEmpty) {
      systemPrompt = 'You are PocketStrike AI, a helpful, intelligent, and concise assistant.';
    }

    if (state.agentMode) {
      const agentImageInstruction =
          'You have full capabilities to generate images using the "generate_image" tool. When the user asks you to generate, create, draw, paint, design, or render an image, artwork, illustration, photo, or wallpaper, ALWAYS call the "generate_image" tool with a detailed, creative visual prompt and "1:1" aspect ratio unless specified otherwise.';
      systemPrompt = systemPrompt.isEmpty
          ? agentImageInstruction
          : '$systemPrompt\n\n$agentImageInstruction';
    }

    if (systemPrompt.isNotEmpty) {
      return [
        ChatMessage(
          id: 'system',
          role: MessageRole.system,
          content: systemPrompt,
          createdAt: DateTime.now(),
        ),
        ...chatMsgs,
      ];
    }
    return chatMsgs;
  }

  Future<void> _persistMessage(
    String conversationId,
    ChatMessage msg, {
    int? promptTokens,
    int? completionTokens,
  }) async {
    String? attsJson;
    if (msg.attachments.isNotEmpty) {
      attsJson = jsonEncode(msg.attachments.map((a) => a.toJson()).toList());
    }
    String? callsJson;
    if (msg.toolCalls.isNotEmpty) {
      callsJson = jsonEncode(msg.toolCalls.map((c) => c.toJson()).toList());
    }

    await ref.read(appDatabaseProvider).messagesDao.insertMessage(
          MessagesCompanion.insert(
            id: msg.id,
            conversationId: conversationId,
            role: msg.role.name,
            content: Value(msg.content),
            toolCallId: Value(msg.toolCallId),
            toolName: Value(msg.toolName),
            toolCallsJson: Value(callsJson),
            attachmentsJson: Value(attsJson),
            promptTokens: Value(promptTokens),
            completionTokens: Value(completionTokens),
            createdAt: msg.createdAt ?? DateTime.now(),
          ),
        );
  }

  Future<void> _maybeAutoTitle(String conversationId, String text) async {
    final conv = await ref
        .read(appDatabaseProvider)
        .conversationsDao
        .getById(conversationId);
    if (conv != null && (conv.title == 'New chat' || conv.title.isEmpty)) {
      final title = text.length > 30 ? '${text.substring(0, 30)}…' : text;
      await ref
          .read(conversationActionsProvider)
          .rename(conversationId, title);
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});
