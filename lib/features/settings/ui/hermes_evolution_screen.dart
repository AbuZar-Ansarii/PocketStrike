import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/agent/data/hermes_memory_store.dart';

class HermesEvolutionScreen extends ConsumerStatefulWidget {
  const HermesEvolutionScreen({super.key});

  @override
  ConsumerState<HermesEvolutionScreen> createState() =>
      _HermesEvolutionScreenState();
}

class _HermesEvolutionScreenState
    extends ConsumerState<HermesEvolutionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _userController;
  late TextEditingController _memoryController;
  late TextEditingController _soulController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final memory = ref.read(hermesMemoryProvider);
    _userController = TextEditingController(text: memory.userProfile);
    _memoryController = TextEditingController(text: memory.memoryBase);
    _soulController = TextEditingController(text: memory.agentSoul);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userController.dispose();
    _memoryController.dispose();
    _soulController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentTab() async {
    final notifier = ref.read(hermesMemoryProvider.notifier);
    if (_tabController.index == 0) {
      await notifier.updateUserProfile(_userController.text);
    } else if (_tabController.index == 1) {
      await notifier.updateMemoryBase(_memoryController.text);
    } else {
      await notifier.updateAgentSoul(_soulController.text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hermes memory updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final state = ref.watch(hermesMemoryProvider);
    final notifier = ref.read(hermesMemoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hermes Self-Evolving Agent',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Memory to Defaults',
            icon: Icon(AppIcons.rotateCcw, size: 18, color: tokens.textSecondary),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Reset Evolution Memory?'),
                  content: const Text(
                    'This will reset USER.md, MEMORY.md, and SOUL.md to default clean states.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await notifier.resetToDefaults();
                final updated = ref.read(hermesMemoryProvider);
                _userController.text = updated.userProfile;
                _memoryController.text = updated.memoryBase;
                _soulController.text = updated.agentSoul;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Memory reset to clean defaults.')),
                  );
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tokens.accent,
          labelColor: tokens.accent,
          unselectedLabelColor: tokens.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 18), text: 'USER.md'),
            Tab(icon: Icon(Icons.psychology, size: 18), text: 'MEMORY.md'),
            Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'SOUL.md'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Auto-Evolve Toggle & Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.glassColor,
              border: Border(bottom: BorderSide(color: tokens.glassBorder)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.sparkles, color: tokens.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autonomous Self-Evolution',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Agent grows with user personality and remembers facts across sessions.',
                        style: TextStyle(
                            fontSize: 11, color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.autoEvolveEnabled,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) => notifier.setAutoEvolve(val),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. USER.md (User Profile & Personality)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USER.md (Learned User Personality & Traits)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: tokens.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _userController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: tokens.glassColor,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              borderSide: BorderSide(color: tokens.glassBorder),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. MEMORY.md (Cross-Session Knowledge Base)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEMORY.md (Persistent Environment & Task Context)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: tokens.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _memoryController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: tokens.glassColor,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              borderSide: BorderSide(color: tokens.glassBorder),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. SOUL.md (Agent Identity & Dynamic Persona)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOUL.md (Hermes Agent Identity & Tone)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: tokens.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _soulController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: tokens.glassColor,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              borderSide: BorderSide(color: tokens.glassBorder),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassButton(
              label: 'Save Evolution Memory',
              icon: AppIcons.save,
              expanded: true,
              onPressed: _saveCurrentTab,
            ),
          ),
        ],
      ),
    );
  }
}
