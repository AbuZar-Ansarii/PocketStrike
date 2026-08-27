import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketstrike/app/app.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/agent/data/cron_task_store.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';
import 'package:pocketstrike/features/mcp/data/mcp_connection_manager.dart';
import 'package:pocketstrike/features/telegram/telegram_service.dart';

class MockTelegramNotifier extends TelegramServiceNotifier {
  @override
  TelegramServiceState build() {
    return const TelegramServiceState(status: TelegramBridgeStatus.disabled);
  }

  @override
  Future<void> startPolling() async {}

  @override
  void stopPolling() {}
}

class MockMcpConnectionsNotifier extends McpConnectionsNotifier {
  @override
  Map<String, McpConnection> build() {
    return const {};
  }

  @override
  Future<void> connectEnabled() async {}
}

class MockCronTaskNotifier extends CronTaskNotifier {
  @override
  List<CronTask> build() => const [];
}

void main() {
  testWidgets('PocketStrike app renders successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'telegram_bridge_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        telegramServiceProvider.overrideWith(MockTelegramNotifier.new),
        mcpConnectionsProvider.overrideWith(MockMcpConnectionsNotifier.new),
        cronTaskProvider.overrideWith(MockCronTaskNotifier.new),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PocketStrikeApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(PocketStrikeApp), findsOneWidget);
  });
}
