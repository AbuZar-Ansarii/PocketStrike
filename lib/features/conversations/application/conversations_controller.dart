import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';

/// Sidebar list: pinned first, then recent.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(appDatabaseProvider).conversationsDao.watchAll();
});

/// The conversation currently open in the chat screen (null = fresh draft).
final currentConversationIdProvider =
    StateProvider<String?>((ref) => null);

final currentConversationProvider = StreamProvider<Conversation?>((ref) {
  final id = ref.watch(currentConversationIdProvider);
  if (id == null) return Stream.value(null);
  return ref
      .watch(appDatabaseProvider)
      .conversationsDao
      .watchAll()
      .map((all) => all.where((c) => c.id == id).firstOrNull);
});

/// Currently selected persona ID for new chats.
final selectedPersonaIdProvider = StateProvider<String?>((ref) => null);

/// Currently active Persona object.
final activePersonaProvider = FutureProvider<Persona?>((ref) async {
  final id = ref.watch(selectedPersonaIdProvider);
  if (id == null) return null;
  final all = await ref.watch(appDatabaseProvider).personasDao.getAll();
  return all.where((p) => p.id == id).firstOrNull;
});

extension ConversationMcpX on Conversation {
  Set<String> get enabledMcpServerIds {
    if (mcpServerIds.isEmpty) return {};
    try {
      final list = jsonDecode(mcpServerIds) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}

/// CRUD for conversations.
class ConversationActions {
  ConversationActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  ConversationsDao get _dao =>
      _ref.read(appDatabaseProvider).conversationsDao;
  MessagesDao get _messagesDao =>
      _ref.read(appDatabaseProvider).messagesDao;

  Future<String> ensureActiveConversation() async {
    var id = _ref.read(currentConversationIdProvider);
    if (id == null) {
      id = await createConversation();
      _ref.read(currentConversationIdProvider.notifier).state = id;
    }
    return id;
  }

  Future<String> createConversation({
    String? personaId,
    String? providerId,
    String? model,
    String source = 'app',
    String? branchedFromId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _dao.upsert(ConversationsCompanion.insert(
      id: id,
      personaId: Value(personaId),
      providerId: Value(providerId),
      model: Value(model),
      source: Value(source),
      branchedFromId: Value(branchedFromId),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Copies an existing thread into a new conversation (branching).
  Future<String> branch(String conversationId) async {
    final source = await _dao.getById(conversationId);
    if (source == null) return conversationId;

    final newId = await createConversation(
      personaId: source.personaId,
      providerId: source.providerId,
      model: source.model,
      branchedFromId: conversationId,
    );
    await _dao.rename(newId, '${source.title} (branch)');

    final messages = await _messagesDao.getForConversation(conversationId);
    for (final m in messages) {
      await _messagesDao.insertMessage(MessagesCompanion.insert(
        id: _uuid.v4(),
        conversationId: newId,
        role: m.role,
        content: Value(m.content),
        toolCallsJson: Value(m.toolCallsJson),
        toolCallId: Value(m.toolCallId),
        toolName: Value(m.toolName),
        attachmentsJson: Value(m.attachmentsJson),
        createdAt: m.createdAt,
      ));
    }
    return newId;
  }

  Future<void> updateEnabledMcpServers(
      String id, Set<String> serverIds) async {
    await _dao.setMcpServerIds(id, jsonEncode(serverIds.toList()));
  }

  Future<void> rename(String id, String title) => _dao.rename(id, title);

  Future<void> togglePin(Conversation conversation) =>
      _dao.setPinned(conversation.id, !conversation.pinned);

  Future<void> delete(String id) async {
    await _messagesDao.deleteForConversation(id);
    await _dao.deleteById(id);
    if (_ref.read(currentConversationIdProvider) == id) {
      _ref.read(currentConversationIdProvider.notifier).state = null;
    }
  }
}

final conversationActionsProvider =
    Provider<ConversationActions>((ref) => ConversationActions(ref));

/// Personas (agent system prompts).
final personasProvider = StreamProvider<List<Persona>>((ref) {
  return ref.watch(appDatabaseProvider).personasDao.watchAll();
});

class PersonaActions {
  PersonaActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  PersonasDao get _dao => _ref.read(appDatabaseProvider).personasDao;

  Future<String> save({
    String? id,
    required String name,
    required String systemPrompt,
    String icon = '🤖',
  }) async {
    final personaId = id ?? _uuid.v4();
    await _dao.upsert(PersonasCompanion.insert(
      id: personaId,
      name: name,
      systemPrompt: Value(systemPrompt),
      icon: Value(icon),
    ));
    return personaId;
  }

  Future<void> savePersona(Persona persona) => save(
        id: persona.id,
        name: persona.name,
        systemPrompt: persona.systemPrompt,
        icon: persona.icon,
      );

  Future<void> deletePersona(String id) => _dao.deleteById(id);

  Future<void> delete(String id) => _dao.deleteById(id);
}

final personaActionsProvider =
    Provider<PersonaActions>((ref) => PersonaActions(ref));
