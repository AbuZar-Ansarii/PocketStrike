import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';

/// Settings screen for model generation parameters (temperature, top_p, max_tokens, penalty).
class ModelParamsScreen extends ConsumerStatefulWidget {
  const ModelParamsScreen({super.key});

  @override
  ConsumerState<ModelParamsScreen> createState() => _ModelParamsScreenState();
}

class _ModelParamsScreenState extends ConsumerState<ModelParamsScreen> {
  double _temperature = 0.7;
  double _topP = 1.0;
  int _maxTokens = 4096;
  double _freqPenalty = 0.0;
  double _presencePenalty = 0.0;
  final _systemPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _temperature = prefs.getDouble('gen_temperature') ?? 0.7;
    _topP = prefs.getDouble('gen_top_p') ?? 1.0;
    _maxTokens = prefs.getInt('gen_max_tokens') ?? 4096;
    _freqPenalty = prefs.getDouble('gen_freq_penalty') ?? 0.0;
    _presencePenalty = prefs.getDouble('gen_presence_penalty') ?? 0.0;
    _systemPromptController.text = prefs.getString('gen_system_prompt') ?? '';
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('gen_temperature', _temperature);
    await prefs.setDouble('gen_top_p', _topP);
    await prefs.setInt('gen_max_tokens', _maxTokens);
    await prefs.setDouble('gen_freq_penalty', _freqPenalty);
    await prefs.setDouble('gen_presence_penalty', _presencePenalty);
    await prefs.setString('gen_system_prompt', _systemPromptController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generation parameters saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Model & Parameters',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Temperature Slider
          _SliderTile(
            title: 'Temperature (${_temperature.toStringAsFixed(2)})',
            subtitle: 'Controls randomness. Higher = creative, Lower = precise.',
            value: _temperature,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            onChanged: (v) => setState(() => _temperature = v),
          ),

          // Top P Slider
          _SliderTile(
            title: 'Top P Nucleus (${_topP.toStringAsFixed(2)})',
            subtitle: 'Alternative to temperature sampling.',
            value: _topP,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (v) => setState(() => _topP = v),
          ),

          // Max Tokens Slider
          _SliderTile(
            title: 'Max Tokens ($_maxTokens)',
            subtitle: 'Maximum token count to generate in a single turn.',
            value: _maxTokens.toDouble(),
            min: 256,
            max: 16384,
            divisions: 63,
            onChanged: (v) => setState(() => _maxTokens = v.toInt()),
          ),

          // Frequency Penalty
          _SliderTile(
            title: 'Frequency Penalty (${_freqPenalty.toStringAsFixed(2)})',
            subtitle: 'Decreases likelihood of repeating exact words.',
            value: _freqPenalty,
            min: -2.0,
            max: 2.0,
            divisions: 40,
            onChanged: (v) => setState(() => _freqPenalty = v),
          ),

          // Presence Penalty
          _SliderTile(
            title: 'Presence Penalty (${_presencePenalty.toStringAsFixed(2)})',
            subtitle: 'Increases likelihood of introducing new topics.',
            value: _presencePenalty,
            min: -2.0,
            max: 2.0,
            divisions: 40,
            onChanged: (v) => setState(() => _presencePenalty = v),
          ),
          const SizedBox(height: 14),

          // System Prompt Override
          TextField(
            controller: _systemPromptController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Global System Prompt (optional)',
              hintText: 'Default global instructions prepended to all chats...',
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 20),

          GlassButton(
            label: 'Save Parameters',
            expanded: true,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.glassColor,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.textSecondary)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: tokens.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
