import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daos.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Conversations,
    Messages,
    Personas,
    McpServers,
    ProviderConfigs,
    AgentRuns,
  ],
  daos: [
    ConversationsDao,
    MessagesDao,
    PersonasDao,
    McpServersDao,
    ProviderConfigsDao,
    AgentRunsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'pocketstrike'));

  /// In-memory constructor for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _seedPersonas();
        },
      );

  Future<void> _seedPersonas() async {
    final now = DateTime.now();
    await batch((batch) {
      batch.insertAll(personas, [
        PersonasCompanion.insert(
          id: 'persona_general',
          name: 'General Assistant',
          systemPrompt: const Value(
            'You are PocketStrike, a precise, friendly AI assistant. '
            'Answer concisely and use markdown when it helps.',
          ),
          icon: const Value('sparkle'),
          isBuiltIn: const Value(true),
        ),
        PersonasCompanion.insert(
          id: 'persona_coding',
          name: 'Coding Agent',
          systemPrompt: const Value(
            'You are PocketStrike, an expert software engineer. '
            'Write correct, idiomatic code with brief explanations. '
            'Prefer complete, runnable snippets.',
          ),
          icon: const Value('code'),
          isBuiltIn: const Value(true),
        ),
        PersonasCompanion.insert(
          id: 'persona_research',
          name: 'Research Agent',
          systemPrompt: const Value(
            'You are PocketStrike, a thorough research assistant. '
            'Cite reasoning steps, compare options, and flag uncertainty.',
          ),
          icon: const Value('magnifyingGlass'),
          isBuiltIn: const Value(true),
        ),
      ]);
    });
    // ignore: avoid_print
    print('Seeded default personas at $now');
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
