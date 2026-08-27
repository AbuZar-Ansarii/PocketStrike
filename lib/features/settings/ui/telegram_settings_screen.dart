import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/core/storage/secure_keys.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/shared/widgets/status_dot.dart';
import 'package:pocketstrike/features/telegram/telegram_service.dart';

class TelegramSettingsScreen extends ConsumerStatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  ConsumerState<TelegramSettingsScreen> createState() =>
      _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState
    extends ConsumerState<TelegramSettingsScreen> {
  final _tokenController = TextEditingController();
  final _chatIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token =
        await ref.read(secureKeyStoreProvider).readTelegramToken();
    final state = ref.read(telegramServiceProvider);
    _tokenController.text = token ?? '';
    _chatIdController.text = state.allowedChatId ?? '';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _tokenController.text.trim();
    final chatId = _chatIdController.text.trim();

    await ref.read(secureKeyStoreProvider).writeTelegramToken(token);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('telegram_bridge_enabled', token.isNotEmpty);
    await prefs.setString('telegram_allowed_chat_id', chatId);

    ref.read(telegramServiceProvider.notifier).startPolling();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram bridge configured!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final state = ref.watch(telegramServiceProvider);

    final statusDotState = switch (state.status) {
      TelegramBridgeStatus.polling => StatusDotState.connected,
      TelegramBridgeStatus.error => StatusDotState.error,
      TelegramBridgeStatus.disabled => StatusDotState.idle,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Telegram Bridge',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.glassColor,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusDot(state: statusDotState),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${state.status.name.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect a Telegram Bot token to query PocketStrike remotely. '
                  'Only messages from your allowed Chat ID will be processed.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bot Token Input
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Bot Token (from @BotFather)',
              hintText: '123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ',
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Allowed Chat ID Input
          TextField(
            controller: _chatIdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Allowed Chat ID (optional filter)',
              hintText: 'e.g. 987654321',
              helperText: 'Leave blank to allow any chat, or restrict to your Telegram ID.',
              helperMaxLines: 2,
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 24/7 Always-On Relay Mode Toggle (OpenClaw Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.glassColor,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: state.alwaysOn
                    ? tokens.accent.withValues(alpha: 0.35)
                    : tokens.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(AppIcons.sparkles, color: tokens.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Always-On 24/7 Relay',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep Telegram agent active in background when app is minimized (Foreground Service).',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: state.alwaysOn,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) {
                    ref.read(telegramServiceProvider.notifier).setAlwaysOn(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Battery Optimization & Commands Tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.glassColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.cpu, size: 14, color: tokens.accent),
                    const SizedBox(width: 6),
                    Text(
                      'HOW TO USE & TEST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                        color: tokens.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Send /start or /id on Telegram to get your Chat ID.\n'
                  '• Send /ping to check agent connectivity.\n'
                  '• Send any question or coding task and PocketStrike processes it with your active AI provider.\n'
                  '• For 24/7 reliability on Android, set Battery Usage for PocketStrike to "Unrestricted" in Android App Settings.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (state.lastError != null) ...[
            Text(
              'Error: ${state.lastError}',
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              if (state.status != TelegramBridgeStatus.disabled)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(telegramServiceProvider.notifier)
                        .stopPolling(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: tokens.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
              if (state.status != TelegramBridgeStatus.disabled)
                const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  label: 'Save & Start Bridge',
                  icon: AppIcons.send,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
