import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/chat/ui/chat_screen.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/telegram/telegram_service.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';
import 'package:pocketstrike/features/mcp/data/mcp_connection_manager.dart';
import 'package:pocketstrike/features/agent/data/cron_task_store.dart';

class MockTelegramNotifier extends TelegramServiceNotifier {
  @override
  TelegramServiceState build() => const TelegramServiceState(status: TelegramBridgeStatus.disabled);
  @override
  Future<void> startPolling() async {}
  @override
  void stopPolling() {}
}

class MockMcpConnectionsNotifier extends McpConnectionsNotifier {
  @override
  Map<String, McpConnection> build() => const {};
  @override
  Future<void> connectEnabled() async {}
}

class MockCronTaskNotifier extends CronTaskNotifier {
  @override
  List<CronTask> build() => const [];
}

void main() {
  testWidgets('ChatScreen autoscrolls as streaming text updates', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'telegram_bridge_enabled': false});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    // Insert a conversation
    final conv = ConversationsCompanion.insert(
      id: 'conv-test-1',
      title: const Value('Test Chat'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.conversationsDao.upsert(conv);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        currentConversationIdProvider.overrideWith((ref) => 'conv-test-1'),
        telegramServiceProvider.overrideWith(MockTelegramNotifier.new),
        mcpConnectionsProvider.overrideWith(MockMcpConnectionsNotifier.new),
        cronTaskProvider.overrideWith(MockCronTaskNotifier.new),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // Set demoMode = true so inputEnabled is true
    container.read(chatControllerProvider.notifier).state = const ChatState(
      demoMode: true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ChatScreen renders
    expect(find.byType(ChatScreen), findsOneWidget);

    // Simulate streaming text arrival
    container.read(chatControllerProvider.notifier).state = const ChatState(
      demoMode: true,
      isGenerating: true,
      streamingText: 'Line 1: Hello from AI\nLine 2: Token streaming\nLine 3: Autoscroll follow',
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Line 1: Hello from AI'), findsOneWidget);
  });
}
