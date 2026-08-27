import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';

class AgentToolsScreen extends ConsumerStatefulWidget {
  const AgentToolsScreen({super.key});

  @override
  ConsumerState<AgentToolsScreen> createState() => _AgentToolsScreenState();
}

class _AgentToolsScreenState extends ConsumerState<AgentToolsScreen> {
  bool _enableFilesystem = true;
  bool _enableWebSearch = true;
  bool _enableCalculator = true;
  bool _enableCodeSandbox = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _enableFilesystem = prefs.getBool('tool_filesystem') ?? true;
    _enableWebSearch = prefs.getBool('tool_websearch') ?? true;
    _enableCalculator = prefs.getBool('tool_calculator') ?? true;
    _enableCodeSandbox = prefs.getBool('tool_codesandbox') ?? true;
  }

  Future<void> _update(String key, bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agent Tools & Capabilities',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolSwitchTile(
            icon: AppIcons.folder,
            title: 'File System Agent Tools',
            subtitle: 'list_files, read_file, write_file, create_folder, delete_file, search_files',
            value: _enableFilesystem,
            onChanged: (v) {
              setState(() => _enableFilesystem = v);
              _update('tool_filesystem', v);
            },
          ),
          _ToolSwitchTile(
            icon: AppIcons.globe,
            title: 'Web Search Tool',
            subtitle: 'Queries web search endpoint for live information',
            value: _enableWebSearch,
            onChanged: (v) {
              setState(() => _enableWebSearch = v);
              _update('tool_websearch', v);
            },
          ),
          _ToolSwitchTile(
            icon: AppIcons.calculator,
            title: 'Arithmetic Calculator',
            subtitle: 'Evaluates basic mathematical expressions',
            value: _enableCalculator,
            onChanged: (v) {
              setState(() => _enableCalculator = v);
              _update('tool_calculator', v);
            },
          ),
          _ToolSwitchTile(
            icon: AppIcons.code,
            title: 'Code Execution Sandbox',
            subtitle: 'Validates and evaluates safe code snippets',
            value: _enableCodeSandbox,
            onChanged: (v) {
              setState(() => _enableCodeSandbox = v);
              _update('tool_codesandbox', v);
            },
          ),
        ],
      ),
    );
  }
}

class _ToolSwitchTile extends StatelessWidget {
  const _ToolSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tokens.glassColor,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.glassBorder),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: tokens.accent),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle, style: TextStyle(color: tokens.textSecondary)),
        value: value,
        activeThumbColor: tokens.accent,
        onChanged: onChanged,
      ),
    );
  }
}
