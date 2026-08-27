import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/confirm_action_sheet.dart';
import 'package:pocketstrike/shared/widgets/empty_state.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/mcp/ui/mcp_toggle_menu.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/chat/ui/widgets/agent_timeline.dart';
import 'package:pocketstrike/features/chat/ui/widgets/app_drawer.dart';
import 'package:pocketstrike/features/chat/ui/widgets/chat_input_bar.dart';
import 'package:pocketstrike/features/chat/ui/widgets/message_bubble.dart';
import 'package:pocketstrike/features/local_models/data/local_model_info.dart';
import 'package:pocketstrike/features/local_models/data/local_model_store.dart';

/// Messages for the open conversation.
final messagesProvider = StreamProvider<List<Message>>((ref) {
  final id = ref.watch(currentConversationIdProvider);
  if (id == null) return Stream.value(const <Message>[]);
  return ref.watch(appDatabaseProvider).messagesDao.watchForConversation(id);
});

/// Main chat surface.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _autoScrollEnabled = true;
  bool _showScrollToBottomBtn = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    // Install the confirmation bridge between the agent engine and the UI.
    ref.read(chatControllerProvider.notifier).confirmHandler =
        (tool, call) => ConfirmActionSheet.show(
              context,
              title: 'Run ${tool.name}?',
              description: tool.description,
              arguments: _decodeArgs(call.argumentsJson),
              showAllowAlways: true,
            );
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isNearBottom = (maxScroll - currentScroll) <= 80;

    if (isNearBottom != _autoScrollEnabled || (!isNearBottom) != _showScrollToBottomBtn) {
      setState(() {
        _autoScrollEnabled = isNearBottom;
        _showScrollToBottomBtn = !isNearBottom;
      });
    }
  }

  Map<String, dynamic> _decodeArgs(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return {'raw': json};
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final chatState = ref.watch(chatControllerProvider);
    final messages = ref.watch(messagesProvider).valueOrNull ?? const [];
    final conversation = ref.watch(currentConversationProvider).valueOrNull;
    final configs = ref.watch(providerConfigsProvider).valueOrNull ?? const [];
    final localStore = ref.watch(localModelStoreProvider);
    final activeLocal = localStore.activeModel;
    final hasProvider = configs.isNotEmpty;
    final inputEnabled = hasProvider || chatState.demoMode || chatState.localMode;

    // Follow streaming text live
    if (chatState.isGenerating && _autoScrollEnabled) {
      _scrollToBottom(animated: false);
    }

    // Surface errors & follow stream lifecycle events
    ref.listen(chatControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(chatControllerProvider.notifier).clearError();
      }

      if (prev?.isGenerating != true && next.isGenerating == true) {
        _autoScrollEnabled = true;
        _showScrollToBottomBtn = false;
        _scrollToBottom(animated: true);
      } else if (next.isGenerating && _autoScrollEnabled) {
        _scrollToBottom(animated: false);
      } else if (prev?.isGenerating == true && next.isGenerating == false) {
        if (_autoScrollEnabled) {
          _scrollToBottom(animated: true);
        }
      }
    });

    ref.listen(messagesProvider, (prev, next) {
      final prevLen = prev?.valueOrNull?.length ?? 0;
      final nextLen = next.valueOrNull?.length ?? 0;
      if (nextLen > prevLen && _autoScrollEnabled) {
        _scrollToBottom(animated: true);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawerScrimColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (drawerContext) => Center(
            child: _GlassIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Open sidebar',
              onPressed: () => Scaffold.of(drawerContext).openDrawer(),
            ),
          ),
        ),
        title: Text(
          conversation?.title ?? 'PocketStrike',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (chatState.status != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Text(
                  chatState.status!,
                  style: Theme.of(context)
                      .textTheme.bodySmall
                      ?.copyWith(color: tokens.textSecondary, fontSize: 11),
                ),
              ),
            ),
          if (chatState.currentMode == ChatMode.agent) const McpToggleMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tokens.glassColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.glassBorder, width: 0.8),
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(AppIcons.moreVertical,
                    size: 16, color: tokens.textSecondary),
                onSelected: (value) async {
                  switch (value) {
                    case 'branch':
                      final id = ref.read(currentConversationIdProvider);
                      if (id != null) {
                        final newId = await ref
                            .read(conversationActionsProvider)
                            .branch(id);
                        if (context.mounted) {
                          context.go('${AppRoutes.chat}/$newId');
                        }
                      }
                    case 'run':
                      final runId = ref.read(chatControllerProvider).runId;
                      if (runId != null && context.mounted) {
                        context.push('${AppRoutes.agentRun}/$runId');
                      }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'branch',
                    child: Text('Branch conversation'),
                  ),
                  if (chatState.runId != null)
                    const PopupMenuItem(
                      value: 'run',
                      child: Text('View agent run'),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3, right: 10),
            child: _GlassIconButton(
              icon: AppIcons.plus,
              accent: true,
              tooltip: 'New Chat',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(currentConversationIdProvider.notifier).state = null;
                context.go(AppRoutes.chat);
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ---- Sleek Compact Glassy 3-Way Mode Switcher Pill ----
          const _ModeSwitchBar(),

          // ---- Active Local Model Status Bar (when Local mode is selected) ----
          if (chatState.localMode)
            _LocalModelStatusBanner(
              model: activeLocal,
              onTap: () => context.push(AppRoutes.settingsLocalModels),
            ),

          Expanded(
            child: !inputEnabled
                ? EmptyState(
                    icon: AppIcons.key,
                    title: 'No AI provider yet',
                    message: 'PocketStrike needs at least one provider '
                        'to chat. Add OpenAI, Claude, Gemini, Groq, '
                        'OpenRouter or Ollama — or switch to Local mode.',
                    actionLabel: 'Add a provider',
                    onAction: () => context.push(AppRoutes.settingsProviders),
                  )
                : (messages.isEmpty && chatState.streamingText.isEmpty)
                    ? EmptyState(
                        icon: chatState.localMode
                            ? (activeLocal?.type == LocalModelType.imageModel
                                ? AppIcons.image
                                : AppIcons.cpu)
                            : (chatState.agentMode ? AppIcons.bot : AppIcons.messageSquare),
                        title: chatState.localMode
                            ? (activeLocal?.type == LocalModelType.imageModel
                                ? 'Offline Image Generation'
                                : '100% Offline Local AI')
                            : (chatState.agentMode ? 'Autonomous Agent' : 'Start a conversation'),
                        message: chatState.localMode
                            ? (activeLocal != null
                                ? (activeLocal.isLoadedInRam
                                    ? '🟢 Loaded in RAM: ${activeLocal.name} (${activeLocal.type == LocalModelType.imageModel ? "${activeLocal.steps} steps" : activeLocal.quantization}, ${activeLocal.formattedRamUsage}). Ready to run!'
                                    : '⚪ ${activeLocal.name} is not loaded in RAM yet. Tap above to load it into memory.')
                                : 'Import and load a .gguf or image model to run on-device.')
                            : (chatState.agentMode
                                ? 'Agent mode is ON — the model can plan and execute tools step by step.'
                                : 'Ask anything. Switch between Chat, Agent & Local mode above.'),
                        actionLabel: chatState.localMode ? 'Manage Local Models' : null,
                        onAction: chatState.localMode
                            ? () => context.push(AppRoutes.settingsLocalModels)
                            : null,
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: Builder(
                              builder: (context) {
                                final visibleMessages = messages
                                    .where((m) => m.role != 'tool')
                                    .toList();
                                return ListView.builder(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                                  itemCount: visibleMessages.length +
                                      (chatState.isGenerating
                                          ? (chatState.agentMode ? 2 : 1)
                                          : 0),
                                  itemBuilder: (context, index) {
                                    if (index < visibleMessages.length) {
                                      final message = visibleMessages[index];
                                      final isLastAssistant =
                                          message.role == 'assistant' &&
                                              index == visibleMessages.length - 1;
                                      return MessageBubble(
                                        key: ValueKey(message.id),
                                        message: message,
                                        isLastAssistant: isLastAssistant,
                                      );
                                    }

                                    final extraIndex =
                                        index - visibleMessages.length;

                                    if (chatState.agentMode) {
                                      // In Agent Mode:
                                      // extraIndex 0 -> Live Agent execution status
                                      // extraIndex 1 -> Streaming reply container
                                      if (extraIndex == 0) {
                                        return AgentTimeline(
                                          steps: chatState.steps,
                                          running: chatState.isGenerating,
                                        );
                                      } else {
                                        return _StreamingBubble(
                                          text: chatState.streamingText,
                                        );
                                      }
                                    } else {
                                      // Non-Agent Mode:
                                      if (chatState.isGeneratingImage) {
                                        return _ImageGenerationLoadingCard(
                                          prompt:
                                              chatState.imageGenerationPrompt ?? '',
                                        );
                                      }
                                      return _StreamingBubble(
                                        text: chatState.streamingText,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          if (_showScrollToBottomBtn)
                            Positioned(
                              bottom: 12,
                              right: 16,
                              child: _ScrollToBottomFloatingButton(
                                isGenerating: chatState.isGenerating,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _autoScrollEnabled = true;
                                    _showScrollToBottomBtn = false;
                                  });
                                  _scrollToBottom(animated: true);
                                },
                              ),
                            ),
                        ],
                      ),
          ),
          ChatInputBar(enabled: inputEnabled),
        ],
      ),
    );
  }
}

/// Floating Scroll-to-Bottom Button with streaming badge indicator
class _ScrollToBottomFloatingButton extends StatelessWidget {
  const _ScrollToBottomFloatingButton({
    required this.onTap,
    required this.isGenerating,
  });

  final VoidCallback onTap;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.terminalSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isGenerating
                  ? tokens.accent.withValues(alpha: 0.6)
                  : tokens.glassBorder,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (isGenerating)
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGenerating) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.accent,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Streaming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isGenerating ? tokens.accent : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active Local Model Status Bar with Glowing Green Dot
class _LocalModelStatusBanner extends StatelessWidget {
  const _LocalModelStatusBanner({
    required this.model,
    required this.onTap,
  });

  final LocalModelInfo? model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final isLoaded = model?.isLoadedInRam ?? false;
    final isImage = model?.type == LocalModelType.imageModel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Material(
        color: tokens.glassColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLoaded
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : tokens.glassBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                // Glowing Green or Gray Status Dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLoaded
                        ? const Color(0xFF10B981)
                        : tokens.textSecondary,
                    boxShadow: isLoaded
                        ? [
                            const BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Model Name & Role
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          model?.name ?? 'No Model Loaded',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.glassBorder.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isImage ? '🎨 Image' : '💬 Chat',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      if (isLoaded) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            model!.formattedRamUsage,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                Icon(
                  AppIcons.settings,
                  size: 13,
                  color: tokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3-Way Mode Switcher (Chat | Agent | Local)
class _ModeSwitchBar extends ConsumerWidget {
  const _ModeSwitchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final chatState = ref.watch(chatControllerProvider);
    final currentMode = chatState.currentMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: tokens.glassColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.glassBorder, width: 0.8),
        ),
        child: Row(
          children: [
            // 1. Chat Mode Segment
            Expanded(
              child: _buildSegment(
                context: context,
                tokens: tokens,
                icon: AppIcons.messageSquare,
                label: 'Chat',
                isSelected: currentMode == ChatMode.chat,
                onTap: () {
                  if (currentMode != ChatMode.chat) {
                    HapticFeedback.selectionClick();
                    ref.read(chatControllerProvider.notifier).setChatMode(ChatMode.chat);
                  }
                },
              ),
            ),
            const SizedBox(width: 2),

            // 2. Agent Mode Segment
            Expanded(
              child: _buildSegment(
                context: context,
                tokens: tokens,
                icon: AppIcons.bot,
                label: 'Agent',
                isSelected: currentMode == ChatMode.agent,
                onTap: () {
                  if (currentMode != ChatMode.agent) {
                    HapticFeedback.selectionClick();
                    ref.read(chatControllerProvider.notifier).setChatMode(ChatMode.agent);
                  }
                },
              ),
            ),
            const SizedBox(width: 2),

            // 3. Local Offline Mode Segment
            Expanded(
              child: _buildSegment(
                context: context,
                tokens: tokens,
                icon: AppIcons.cpu,
                label: 'Local',
                isSelected: currentMode == ChatMode.local,
                onTap: () {
                  if (currentMode != ChatMode.local) {
                    HapticFeedback.selectionClick();
                    ref.read(chatControllerProvider.notifier).setChatMode(ChatMode.local);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required dynamic tokens,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final color = accent ? tokens.accent : tokens.textSecondary;

    Widget child = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: accent
            ? tokens.accent.withValues(alpha: 0.15)
            : tokens.glassColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent
              ? tokens.accent.withValues(alpha: 0.4)
              : tokens.glassBorder,
          width: 0.8,
        ),
      ),
      child: Icon(icon, color: color, size: 16),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

/// Live bubble for the in-flight assistant reply.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final fake = Message(
      id: 'streaming',
      conversationId: '',
      role: 'assistant',
      content: text,
      createdAt: DateTime.now(),
    );
    return MessageBubble(message: fake, isStreaming: true);
  }
}

/// Live dedicated image generation card with fill bar and live elapsed time.
class _ImageGenerationLoadingCard extends StatefulWidget {
  const _ImageGenerationLoadingCard({required this.prompt});

  final String prompt;

  @override
  State<_ImageGenerationLoadingCard> createState() =>
      _ImageGenerationLoadingCardState();
}

class _ImageGenerationLoadingCardState
    extends State<_ImageGenerationLoadingCard>
    with SingleTickerProviderStateMixin {
  late Stopwatch _stopwatch;
  late Timer _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (mounted) setState(() {});
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final elapsedSec = (_stopwatch.elapsedMilliseconds / 1000.0);
    // Smooth progress calculation asymptotic towards ~95%
    final progress = (1.0 - exp(-elapsedSec / 4.0)).clamp(0.06, 0.96);

    final cleanPrompt = widget.prompt
        .replaceFirst(RegExp(r'^/image\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^/img\s*', caseSensitive: false), '')
        .trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.86,
          decoration: BoxDecoration(
            color: tokens.glassColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.accent.withValues(alpha: 0.35 + _pulseController.value * 0.35),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.12 * _pulseController.value),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.image,
                          size: 14,
                          color: tokens.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Generating Image…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // Live Time Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tokens.glassBorder.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 12,
                              color: tokens.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${elapsedSec.toStringAsFixed(1)}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Art Placeholder Skeleton
                Container(
                  height: 130,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: tokens.glassBorder.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.glassBorder.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Glow Center Orb
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tokens.accent.withValues(
                                alpha: 0.2 + _pulseController.value * 0.25,
                              ),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 26,
                            color: tokens.accent.withValues(
                              alpha: 0.8 + _pulseController.value * 0.2,
                            ),
                          ),
                          if (cleanPrompt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '"$cleanPrompt"',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom Progress Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Smooth Filling Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: tokens.glassBorder.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Synthesizing diffusion steps…',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              color: tokens.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


