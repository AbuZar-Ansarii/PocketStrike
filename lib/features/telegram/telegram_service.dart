import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/core/storage/secure_keys.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';

enum TelegramBridgeStatus { disabled, polling, error }

class TelegramServiceState {
  const TelegramServiceState({
    this.status = TelegramBridgeStatus.disabled,
    this.botName,
    this.allowedChatId,
    this.lastError,
    this.alwaysOn = true,
  });

  final TelegramBridgeStatus status;
  final String? botName;
  final String? allowedChatId;
  final String? lastError;
  final bool alwaysOn;

  TelegramServiceState copyWith({
    TelegramBridgeStatus? status,
    String? botName,
    String? allowedChatId,
    String? lastError,
    bool? alwaysOn,
    bool clearLastError = false,
  }) =>
      TelegramServiceState(
        status: status ?? this.status,
        botName: botName ?? this.botName,
        allowedChatId: allowedChatId ?? this.allowedChatId,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        alwaysOn: alwaysOn ?? this.alwaysOn,
      );
}

final telegramServiceProvider =
    NotifierProvider<TelegramServiceNotifier, TelegramServiceState>(
        TelegramServiceNotifier.new);

class TelegramServiceNotifier extends Notifier<TelegramServiceState> {
  Timer? _pollingTimer;
  int _lastUpdateId = 0;
  bool _isPolling = false;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  TelegramServiceState build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    });

    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool('telegram_bridge_enabled') ?? false;
    final chatId = prefs.getString('telegram_allowed_chat_id');
    final alwaysOn = prefs.getBool('telegram_always_on') ?? true;

    if (enabled) {
      Future.microtask(() => startPolling());
    }
    return TelegramServiceState(
      status: enabled ? TelegramBridgeStatus.polling : TelegramBridgeStatus.disabled,
      allowedChatId: chatId,
      alwaysOn: alwaysOn,
    );
  }

  Future<void> setAlwaysOn(bool enabled) async {
    state = state.copyWith(alwaysOn: enabled);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('telegram_always_on', enabled);

    try {
      final bgService = FlutterBackgroundService();
      final isRunning = await bgService.isRunning();
      if (enabled && state.status == TelegramBridgeStatus.polling) {
        if (!isRunning) {
          await bgService.startService();
        }
      } else {
        if (isRunning) {
          bgService.invoke('stopService');
        }
      }
    } catch (_) {}
  }

  Future<void> startPolling() async {
    final token = await ref.read(secureKeyStoreProvider).readTelegramToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        status: TelegramBridgeStatus.error,
        lastError: 'Bot token not found in secure storage.',
      );
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final chatId = prefs.getString('telegram_allowed_chat_id');

    try {
      // Validate token & query bot info
      final me = await _dio.get('https://api.telegram.org/bot$token/getMe');
      final botUser = me.data?['result']?['username'] as String?;

      state = state.copyWith(
        status: TelegramBridgeStatus.polling,
        botName: botUser != null ? '@$botUser' : 'PocketStrike Bot',
        allowedChatId: chatId,
        clearLastError: true,
      );

      // Start Android 24/7 background foreground service if alwaysOn is enabled
      if (state.alwaysOn) {
        try {
          final bgService = FlutterBackgroundService();
          if (!await bgService.isRunning()) {
            await bgService.startService();
          }
        } catch (_) {}
      }

      // On startup, query the latest update_id so old stale updates are acknowledged
      if (_lastUpdateId == 0) {
        try {
          final initRes = await _dio.get(
            'https://api.telegram.org/bot$token/getUpdates',
            queryParameters: {'offset': -1, 'timeout': 0},
          );
          final initUpdates = initRes.data?['result'] as List? ?? [];
          if (initUpdates.isNotEmpty) {
            final last = initUpdates.last as Map<String, dynamic>;
            _lastUpdateId = (last['update_id'] as int? ?? 0);
          }
        } catch (_) {}
      }

      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _pollUpdates(token),
      );
    } catch (e) {
      state = state.copyWith(
        status: TelegramBridgeStatus.error,
        lastError: 'Failed to connect to Telegram API: ${e.toString()}',
      );
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {}
    state = state.copyWith(status: TelegramBridgeStatus.disabled);
  }

  Future<void> _pollUpdates(String token) async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      final res = await _dio.get(
        'https://api.telegram.org/bot$token/getUpdates',
        queryParameters: {
          'offset': _lastUpdateId + 1,
          'timeout': 5,
        },
      );

      final updates = res.data?['result'] as List? ?? [];
      for (final update in updates) {
        if (update is! Map<String, dynamic>) continue;
        final updateId = update['update_id'] as int;
        if (updateId > _lastUpdateId) _lastUpdateId = updateId;

        final message = update['message'] as Map<String, dynamic>?;
        if (message == null) continue;

        final text = message['text'] as String? ?? '';
        final chatId = message['chat']?['id']?.toString() ?? '';
        final fromUser = message['from']?['first_name'] as String? ?? 'User';

        if (chatId.isEmpty) continue;

        // Security check for allowed chat ID
        if (state.allowedChatId != null &&
            state.allowedChatId!.trim().isNotEmpty &&
            state.allowedChatId!.trim() != chatId.trim()) {
          // If user sends /start or /id, send their chat ID so they can configure it
          if (text.startsWith('/start') || text.startsWith('/id')) {
            await _sendTelegramMessage(
              token,
              chatId,
              '🔒 **PocketStrike Security Guard**\n\n'
              'This bot is currently locked to a specific Allowed Chat ID in the mobile app.\n\n'
              '👉 **Your Chat ID is:** `$chatId`\n\n'
              'To allow messages from this account, add `$chatId` under **Settings > Telegram Bridge** in your PocketStrike mobile app.',
            );
          }
          continue;
        }

        if (text.isNotEmpty) {
          await _handleTelegramMessage(token, chatId, fromUser, text);
        }
      }
    } catch (_) {
      // Keep polling silently on network glitches
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _handleTelegramMessage(
    String token,
    String chatId,
    String fromUser,
    String text,
  ) async {
    final trimmed = text.trim();

    // 1. Built-in command handlers
    if (trimmed == '/start' || trimmed == '/help') {
      await _sendTelegramMessage(
        token,
        chatId,
        '👋 **Hello $fromUser! Welcome to PocketStrike AI.**\n\n'
        'Your phone is now acting as your autonomous remote AI workstation.\n\n'
        '📌 **Your Chat ID:** `$chatId`\n'
        '🤖 **Bot Status:** Online & Connected\n\n'
        'Send any prompt, task, or question, and PocketStrike will compute the answer directly on your mobile device!',
      );
      return;
    }

    if (trimmed == '/id') {
      await _sendTelegramMessage(
        token,
        chatId,
        '🆔 **Your Telegram Chat ID:** `$chatId`',
      );
      return;
    }

    if (trimmed == '/ping') {
      await _sendTelegramMessage(
        token,
        chatId,
        '🏓 **Pong!** PocketStrike Mobile Agent is online and connected.',
      );
      return;
    }

    // 2. Check if an AI provider exists
    final activeConfig = await ref.read(activeProviderConfigProvider.future);
    final demoMode = ref.read(chatControllerProvider).demoMode;

    if (activeConfig == null && !demoMode) {
      await _sendTelegramMessage(
        token,
        chatId,
        '⚠️ **PocketStrike Error**: No AI Provider configured in the mobile app.\n\n'
        'Please open PocketStrike on your phone and add an AI provider key (OpenAI, Claude, Gemini, Groq, or Ollama) in **Settings > AI Providers**.',
      );
      return;
    }

    // 3. Resolve or create a persistent Telegram conversation for this chat ID
    final db = ref.read(appDatabaseProvider);
    final allConversations = await db.conversationsDao.getAll();
    final telegramConv = allConversations.where(
      (c) => c.source == 'telegram_$chatId' || c.source == 'telegram',
    ).firstOrNull;

    String convId;
    if (telegramConv != null) {
      convId = telegramConv.id;
      await db.conversationsDao.rename(convId, 'Telegram: ${trimmed.take(24)}');
    } else {
      final conversationActions = ref.read(conversationActionsProvider);
      convId = await conversationActions.createConversation(
        source: 'telegram_$chatId',
      );
      await db.conversationsDao.rename(convId, 'Telegram: ${trimmed.take(24)}');
    }

    // Set active conversation ID
    ref.read(currentConversationIdProvider.notifier).state = convId;

    // 4. Send typing indicator to Telegram
    await _sendChatAction(token, chatId, 'typing');

    try {
      // Execute message generation via ChatController
      await ref.read(chatControllerProvider.notifier).sendMessage(text: trimmed);

      // Check for controller error
      final chatState = ref.read(chatControllerProvider);
      if (chatState.error != null && chatState.error!.isNotEmpty) {
        await _sendTelegramMessage(
          token,
          chatId,
          '⚠️ **AI Generation Error**:\n${chatState.error}',
        );
        ref.read(chatControllerProvider.notifier).clearError();
        return;
      }

      // Fetch the generated assistant message
      final messages = await db.messagesDao.getForConversation(convId);
      final lastAssistantMsg =
          messages.where((m) => m.role == 'assistant').lastOrNull;

      if (lastAssistantMsg != null && lastAssistantMsg.content.trim().isNotEmpty) {
        await _sendTelegramMessage(token, chatId, lastAssistantMsg.content.trim());
      } else {
        await _sendTelegramMessage(
          token,
          chatId,
          '⚡ PocketStrike processed your request.',
        );
      }
    } catch (e) {
      await _sendTelegramMessage(
        token,
        chatId,
        '❌ **Error executing prompt**:\n${e.toString()}',
      );
    }
  }

  /// Sends a chat action like 'typing'
  Future<void> _sendChatAction(String token, String chatId, String action) async {
    try {
      await _dio.post(
        'https://api.telegram.org/bot$token/sendChatAction',
        data: {
          'chat_id': chatId,
          'action': action,
        },
      );
    } catch (_) {}
  }

  /// Sends text message to Telegram with auto-chunking for messages > 4000 chars.
  Future<void> _sendTelegramMessage(String token, String chatId, String text) async {
    const maxChunk = 4000;
    try {
      if (text.length <= maxChunk) {
        await _dio.post(
          'https://api.telegram.org/bot$token/sendMessage',
          data: {
            'chat_id': chatId,
            'text': text,
          },
        );
        return;
      }

      // Chunk long messages
      for (var i = 0; i < text.length; i += maxChunk) {
        final end = (i + maxChunk < text.length) ? i + maxChunk : text.length;
        final chunk = text.substring(i, end);
        await _dio.post(
          'https://api.telegram.org/bot$token/sendMessage',
          data: {
            'chat_id': chatId,
            'text': chunk,
          },
        );
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      // Fallback in case of formatting error
      try {
        await _dio.post(
          'https://api.telegram.org/bot$token/sendMessage',
          data: {
            'chat_id': chatId,
            'text': text.take(4000),
          },
        );
      } catch (_) {}
    }
  }

  /// Sends an autonomous notification or reminder alert to Telegram.
  Future<void> postNotification(String text) async {
    final token = await ref.read(secureKeyStoreProvider).readTelegramToken();
    final chatId = state.allowedChatId;
    if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) return;
    await _sendTelegramMessage(token, chatId, text);
  }
}

extension StringTakeX on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}
