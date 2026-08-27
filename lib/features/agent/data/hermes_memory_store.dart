import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';

/// Hermes Self-Evolving Data Store (USER.md, MEMORY.md, SOUL.md).
class HermesMemoryState {
  const HermesMemoryState({
    required this.userProfile,
    required this.memoryBase,
    required this.agentSoul,
    this.autoEvolveEnabled = true,
  });

  /// Learned user personality, habits, preferences, and style (USER.md).
  final String userProfile;

  /// Long-term cross-session knowledge base & environment facts (MEMORY.md).
  final String memoryBase;

  /// Dynamic agent identity, persona, & learned relationship dynamic (SOUL.md).
  final String agentSoul;

  /// Whether the agent automatically learns and updates memories during chats.
  final bool autoEvolveEnabled;

  HermesMemoryState copyWith({
    String? userProfile,
    String? memoryBase,
    String? agentSoul,
    bool? autoEvolveEnabled,
  }) =>
      HermesMemoryState(
        userProfile: userProfile ?? this.userProfile,
        memoryBase: memoryBase ?? this.memoryBase,
        agentSoul: agentSoul ?? this.agentSoul,
        autoEvolveEnabled: autoEvolveEnabled ?? this.autoEvolveEnabled,
      );
}

final hermesMemoryProvider =
    NotifierProvider<HermesMemoryNotifier, HermesMemoryState>(
        HermesMemoryNotifier.new);

class HermesMemoryNotifier extends Notifier<HermesMemoryState> {
  static const _kUserProfileKey = 'hermes_user_md';
  static const _kMemoryBaseKey = 'hermes_memory_md';
  static const _kAgentSoulKey = 'hermes_soul_md';
  static const _kAutoEvolveKey = 'hermes_auto_evolve';

  @override
  HermesMemoryState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    var userMd = prefs.getString(_kUserProfileKey);
    if (userMd == null || userMd.contains('Tech Stack: Flutter, Dart, Python')) {
      userMd = '# USER PROFILE & PREFERENCES\n'
          '• Status: Learning user preferences dynamically through conversation.\n'
          '• Communication Style: Helpful, clear, polite, and adaptive.\n';
      prefs.setString(_kUserProfileKey, userMd);
    }

    var memoryMd = prefs.getString(_kMemoryBaseKey);
    if (memoryMd == null || memoryMd.contains('macOS developer workstation')) {
      memoryMd = '# LONG-TERM MEMORY & KNOWLEDGE\n'
          '• Client: PocketStrike AI Mobile Workstation.\n'
          '• Notes: Ready to learn facts and context provided by the user.\n';
      prefs.setString(_kMemoryBaseKey, memoryMd);
    }

    var soulMd = prefs.getString(_kAgentSoulKey);
    if (soulMd == null || soulMd.contains('Creator & Developer: Created and built by Mohd Abuzar.')) {
      soulMd = '# POCKETSTRIKE AGENT SOUL & IDENTITY\n'
          '• Core Identity: PocketStrike AI - Autonomous Mobile AI Assistant.\n'
          '• Tone: Adaptive, intelligent, sharp, polite, and helpful.\n'
          '• Purpose: Assist the current user with tasks, answer questions accurately, and adapt to their workflow.\n'
          '• Origin: Developed by Mohd Abuzar.\n';
      prefs.setString(_kAgentSoulKey, soulMd);
    }

    final autoEvolve = prefs.getBool(_kAutoEvolveKey) ?? true;

    return HermesMemoryState(
      userProfile: userMd,
      memoryBase: memoryMd,
      agentSoul: soulMd,
      autoEvolveEnabled: autoEvolve,
    );
  }

  Future<void> updateUserProfile(String content) async {
    state = state.copyWith(userProfile: content);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kUserProfileKey, content);
  }

  Future<void> updateMemoryBase(String content) async {
    state = state.copyWith(memoryBase: content);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kMemoryBaseKey, content);
  }

  Future<void> updateAgentSoul(String content) async {
    state = state.copyWith(agentSoul: content);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kAgentSoulKey, content);
  }

  Future<void> setAutoEvolve(bool enabled) async {
    state = state.copyWith(autoEvolveEnabled: enabled);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kAutoEvolveKey, enabled);
  }

  /// Appends a new learned trait to USER.md.
  Future<void> addPreference(String trait) async {
    final updated = '${state.userProfile.trim()}\n• $trait\n';
    await updateUserProfile(updated);
  }

  /// Appends a new fact to MEMORY.md.
  Future<void> addFact(String fact) async {
    final updated = '${state.memoryBase.trim()}\n• $fact\n';
    await updateMemoryBase(updated);
  }

  /// Appends a persona rule to SOUL.md.
  Future<void> addSoulTrait(String trait) async {
    final updated = '${state.agentSoul.trim()}\n• $trait\n';
    await updateAgentSoul(updated);
  }

  /// Resets all memory files (USER.md, MEMORY.md, SOUL.md) back to clean initial states.
  Future<void> resetToDefaults() async {
    const userMd = '# USER PROFILE & PREFERENCES\n'
        '• Status: Learning user preferences dynamically through conversation.\n'
        '• Communication Style: Helpful, clear, polite, and adaptive.\n';
    const memoryMd = '# LONG-TERM MEMORY & KNOWLEDGE\n'
        '• Client: PocketStrike AI Mobile Workstation.\n'
        '• Notes: Ready to learn facts and context provided by the user.\n';
    const soulMd = '# POCKETSTRIKE AGENT SOUL & IDENTITY\n'
        '• Core Identity: PocketStrike AI - Autonomous Mobile AI Assistant.\n'
        '• Tone: Adaptive, intelligent, sharp, polite, and helpful.\n'
        '• Purpose: Assist the current user with tasks, answer questions accurately, and adapt to their workflow.\n'
        '• Origin: Developed by Mohd Abuzar.\n';

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kUserProfileKey, userMd);
    await prefs.setString(_kMemoryBaseKey, memoryMd);
    await prefs.setString(_kAgentSoulKey, soulMd);

    state = state.copyWith(
      userProfile: userMd,
      memoryBase: memoryMd,
      agentSoul: soulMd,
    );
  }

  /// Generates the unified PocketStrike System Prompt context.
  String buildHermesSystemPrompt() {
    return '''
==================================================
POCKETSTRIKE SYSTEM CONTEXT & IDENTITY
==================================================
IDENTITY: You are PocketStrike AI, an intelligent mobile AI assistant and autonomous agent workstation.
CREATOR ATTRIBUTION: PocketStrike was created and developed by Mohd Abuzar. If asked "Who built you?" or "Who created you?", state that PocketStrike was created by Mohd Abuzar.

CRITICAL USER DISTINCTION:
- The person chatting with you right now is the END USER of the app.
- Do NOT assume or pretend the current user is Mohd Abuzar or that they built this app.
- Treat the current user as an independent person. Listen to their questions, learn their preferences as you converse, and adapt to their needs.
- Never refer to yourself as Hermes.

${state.userProfile}

${state.memoryBase}

${state.agentSoul}
==================================================
INSTRUCTIONS:
1. Respond helpfully, politely, and intelligently to the user.
2. If the user shares their name, preferences, or tasks, use self-evolution tools (learn_user_preference, remember_fact, update_agent_soul) to remember them for future sessions.
''';
  }

  /// Hermes Self-Evolution Agent Tools.
  List<AgentTool> buildTools() {
    return [
      AgentTool(
        name: 'learn_user_preference',
        description:
            'Saves a newly discovered user preference, communication style, or personal habit into long-term USER.md memory.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'preference': {
              'type': 'string',
              'description':
                  'The user trait or preference to remember (e.g. "Prefers TypeScript over JS").',
            },
          },
          'required': ['preference'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final pref = args['preference'] as String? ?? '';
          if (pref.trim().isEmpty) return 'Error: Preference cannot be empty.';
          await addPreference(pref.trim());
          return 'Learned and saved user preference into USER.md: "$pref"';
        },
      ),
      AgentTool(
        name: 'remember_fact',
        description:
            'Stores an important environment fact, project detail, or task insight into persistent MEMORY.md across sessions.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'fact': {
              'type': 'string',
              'description':
                  'The fact or project context to remember for future chats.',
            },
          },
          'required': ['fact'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final fact = args['fact'] as String? ?? '';
          if (fact.trim().isEmpty) return 'Error: Fact cannot be empty.';
          await addFact(fact.trim());
          return 'Stored fact into persistent MEMORY.md: "$fact"';
        },
      ),
      AgentTool(
        name: 'update_agent_soul',
        description:
            'Refines the agent’s personality, identity, or communication dynamic in SOUL.md to complement the user.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'trait': {
              'type': 'string',
              'description':
                  'The persona trait or communication rule to adopt.',
            },
          },
          'required': ['trait'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final trait = args['trait'] as String? ?? '';
          if (trait.trim().isEmpty) return 'Error: Trait cannot be empty.';
          await addSoulTrait(trait.trim());
          return 'Evolved agent soul in SOUL.md: "$trait"';
        },
      ),
    ];
  }
}
