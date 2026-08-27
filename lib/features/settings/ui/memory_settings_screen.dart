import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';

class MemorySettingsScreen extends ConsumerStatefulWidget {
  const MemorySettingsScreen({super.key});

  @override
  ConsumerState<MemorySettingsScreen> createState() =>
      _MemorySettingsScreenState();
}

class _MemorySettingsScreenState extends ConsumerState<MemorySettingsScreen> {
  int _contextWindowSize = 20;
  bool _enableRAG = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _contextWindowSize = prefs.getInt('memory_context_window') ?? 20;
    _enableRAG = prefs.getBool('memory_enable_rag') ?? true;
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('memory_context_window', _contextWindowSize);
    await prefs.setBool('memory_enable_rag', _enableRAG);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Memory & Context',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    Icon(AppIcons.brain,
                        color: tokens.accent, size: 20),
                    const SizedBox(width: 8),
                    Text('Agent Memory & Recall',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Short-term memory controls how many previous message turns are sent '
                  'in the context window. Long-term memory enables local keyword/vector recall.',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'CONTEXT WINDOW TURNS ($_contextWindowSize messages)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                ),
          ),
          Slider(
            value: _contextWindowSize.toDouble(),
            min: 4,
            max: 100,
            divisions: 24,
            activeColor: tokens.accent,
            onChanged: (val) {
              setState(() => _contextWindowSize = val.toInt());
              _save();
            },
          ),
          const SizedBox(height: 14),

          SwitchListTile(
            title: const Text('Enable Long-Term RAG Memory Store'),
            subtitle: const Text(
                'Uses local indexing to recall relevant past facts across sessions'),
            value: _enableRAG,
            activeThumbColor: tokens.accent,
            onChanged: (val) {
              setState(() => _enableRAG = val);
              _save();
            },
          ),
        ],
      ),
    );
  }
}
