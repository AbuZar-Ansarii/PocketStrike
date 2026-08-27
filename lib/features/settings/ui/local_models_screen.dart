import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/features/local_models/data/local_model_info.dart';
import 'package:pocketstrike/features/local_models/data/local_model_store.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_card.dart';

class LocalModelsScreen extends ConsumerStatefulWidget {
  const LocalModelsScreen({super.key});

  @override
  ConsumerState<LocalModelsScreen> createState() => _LocalModelsScreenState();
}

class _LocalModelsScreenState extends ConsumerState<LocalModelsScreen> {
  String? _expandedModelId;
  int _selectedFilterIndex = 0; // 0: All, 1: Chat, 2: Image

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final state = ref.watch(localModelStoreProvider);
    final notifier = ref.read(localModelStoreProvider.notifier);

    final totalRamGb = state.totalDeviceRamGb;
    final allocatedRamGb = state.totalAllocatedRamMb / 1024.0;
    final ramUsagePercent = (allocatedRamGb / totalRamGb).clamp(0.0, 1.0);

    final uncensoredModels =
        state.models.where((m) => m.isUncensored).toList();
    final standardChatModels = state.models
        .where((m) =>
            (m.type == LocalModelType.chatGguf ||
                m.type == LocalModelType.uncensoredGguf) &&
            !m.isUncensored)
        .toList();
    final imageModels = state.models
        .where((m) => m.type == LocalModelType.imageModel)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Local & Offline Models',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.plus, size: 20),
            tooltip: 'Import GGUF / Model',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final imported = await notifier.importModelFromFile();
              if (imported != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Imported "${imported.name}" successfully!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Device RAM Memory Gauge
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.cpu, size: 18, color: tokens.accent),
                    const SizedBox(width: 8),
                    Text(
                      'DEVICE RAM ALLOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${allocatedRamGb.toStringAsFixed(2)} / ${totalRamGb.toStringAsFixed(1)} GB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ramUsagePercent,
                    minHeight: 8,
                    backgroundColor: tokens.glassBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ramUsagePercent > 0.85
                          ? Colors.orangeAccent
                          : tokens.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.models.any((m) => m.isLoadedInRam)
                      ? '⚡ Active models are loaded into RAM for zero-latency, 100% private execution.'
                      : '⚪ No models currently loaded in RAM. Tap "Load into RAM" on any model below.',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Import Button
          OutlinedButton.icon(
            icon: Icon(AppIcons.upload, size: 16, color: tokens.accent),
            label: const Text(
              'Import .GGUF / Model from Storage',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: tokens.glassColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: tokens.accent.withValues(alpha: 0.4),
                width: 0.8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final imported = await notifier.importModelFromFile();
              if (imported != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Imported "${imported.name}" successfully!'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // 3. Category Filter Tabs (All / Uncensored / Standard Chat / Image Models)
          Container(
            decoration: BoxDecoration(
              color: tokens.glassColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.glassBorder, width: 0.8),
            ),
            padding: const EdgeInsets.all(4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab(
                    index: 0,
                    label: 'All (${state.models.length})',
                    icon: AppIcons.layers,
                    tokens: tokens,
                  ),
                  const SizedBox(width: 4),
                  _buildFilterTab(
                    index: 1,
                    label: '🔥 Uncensored (${uncensoredModels.length})',
                    icon: AppIcons.zap,
                    tokens: tokens,
                  ),
                  const SizedBox(width: 4),
                  _buildFilterTab(
                    index: 2,
                    label: '💬 Standard (${standardChatModels.length})',
                    icon: AppIcons.messageSquare,
                    tokens: tokens,
                  ),
                  const SizedBox(width: 4),
                  _buildFilterTab(
                    index: 3,
                    label: '🎨 Image (${imageModels.length})',
                    icon: AppIcons.image,
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. 🔥 Uncensored Models Section
          if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) ...[
            _buildSectionHeader(
              title: '🔥 UNCENSORED & ABLITERATED SLMS (${uncensoredModels.length})',
              subtitle: 'Zero alignment refusals & abliterated weights for unrestricted edge tasks.',
              icon: AppIcons.zap,
              color: Colors.deepOrangeAccent,
              tokens: tokens,
            ),
            if (uncensoredModels.isEmpty)
              _buildEmptyCategoryCard(
                title: 'No Uncensored Models Found',
                subtitle: 'Download or import abliterated / heretic GGUFs for unrestricted local generation.',
                icon: AppIcons.zap,
                tokens: tokens,
              )
            else
              ...uncensoredModels.map((m) => _buildModelCard(m, tokens, state, notifier)),
            const SizedBox(height: 14),
          ],

          // 5. 💬 Standard Chat Models Section
          if (_selectedFilterIndex == 0 || _selectedFilterIndex == 2) ...[
            _buildSectionHeader(
              title: '💬 STANDARD CHAT & REASONING (${standardChatModels.length})',
              subtitle: 'GGUF LLM models for offline intelligence, text generation & agents.',
              icon: AppIcons.messageSquare,
              color: tokens.accent,
              tokens: tokens,
            ),
            if (standardChatModels.isEmpty)
              _buildEmptyCategoryCard(
                title: 'No Standard Chat Models Found',
                subtitle: 'Import .gguf files (e.g. Qwen, Llama, DeepSeek) to chat 100% offline.',
                icon: AppIcons.cpu,
                tokens: tokens,
              )
            else
              ...standardChatModels.map((m) => _buildModelCard(m, tokens, state, notifier)),
            const SizedBox(height: 14),
          ],

          // 6. 🎨 Image Models Section
          if (_selectedFilterIndex == 0 || _selectedFilterIndex == 3) ...[
            _buildSectionHeader(
              title: '🎨 IMAGE & DIFFUSION MODELS (${imageModels.length})',
              subtitle: 'Neural diffusion models for generating images & visual artwork.',
              icon: AppIcons.image,
              color: Colors.purpleAccent,
              tokens: tokens,
            ),
            if (imageModels.isEmpty)
              _buildEmptyCategoryCard(
                title: 'No Image Models Found',
                subtitle: 'Import .safetensors or diffusion checkpoints for on-device image generation.',
                icon: AppIcons.image,
                tokens: tokens,
              )
            else
              ...imageModels.map((m) => _buildModelCard(m, tokens, state, notifier)),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 8),

          // 6. Recommended Models Guide Card
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.info, size: 16, color: tokens.accent),
                    const SizedBox(width: 6),
                    Text(
                      'HOW TO DOWNLOAD GGUF MODELS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Download any quantized GGUF or image model from Hugging Face:\n'
                  '   • Llama-3.2-3B-Instruct.Q4_K_M.gguf\n'
                  '   • DeepSeek-R1-Distill-Qwen-1.5B.Q4_K_M.gguf\n'
                  '   • SD-Turbo-Image-Gen.gguf (for image generation)\n'
                  '2. Tap "Import .GGUF / Model from Storage" above.\n'
                  '3. Set model role (Chat LLM or Image Gen), tap "Load into RAM", and enjoy 100% offline generation!',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required IconData icon,
    required GlassTokens tokens,
  }) {
    final isSelected = _selectedFilterIndex == index;
    final isUncensoredTab = index == 1;
    final activeColor =
        isUncensoredTab ? Colors.deepOrangeAccent : tokens.accent;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isSelected
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.55), width: 0.8)
              : Border.all(color: Colors.transparent, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : tokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required GlassTokens tokens,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required GlassTokens tokens,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 24, color: tokens.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(
    LocalModelInfo model,
    GlassTokens tokens,
    LocalModelState state,
    LocalModelStoreNotifier notifier,
  ) {
    final isExpanded = _expandedModelId == model.id;
    final isActive = state.activeModelId == model.id;
    final isDownloaded = model.isDownloaded;
    final isDownloading = state.isDownloading(model.id);
    final downloadProgress = state.getProgress(model.id);
    final downloadStatus = state.getStatus(model.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(
                  model.type == LocalModelType.imageModel
                      ? AppIcons.image
                      : AppIcons.cpu,
                  size: 18,
                  color: tokens.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (model.isUncensored)
                            _buildTag(
                              '🔥 UNCENSORED',
                              tokens,
                              color: Colors.deepOrangeAccent,
                              bgColor: Colors.deepOrangeAccent
                                  .withValues(alpha: 0.16),
                            )
                          else
                            _buildTag(
                              model.type == LocalModelType.imageModel
                                  ? '🎨 IMAGE'
                                  : '💬 CHAT LLM',
                              tokens,
                            ),
                          _buildTag(model.quantization, tokens),
                          _buildTag(model.formattedSize, tokens),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status Chip with Dynamic State Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: model.isLoadedInRam
                        ? const Color(0xFF10B981).withValues(alpha: 0.18)
                        : isDownloading
                            ? tokens.accent.withValues(alpha: 0.18)
                            : isDownloaded
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : tokens.glassBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: model.isLoadedInRam
                          ? const Color(0xFF10B981).withValues(alpha: 0.6)
                          : isDownloading
                              ? tokens.accent.withValues(alpha: 0.6)
                              : isDownloaded
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : tokens.glassBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: model.isLoadedInRam || isDownloaded
                              ? const Color(0xFF10B981)
                              : isDownloading
                                  ? tokens.accent
                                  : tokens.textSecondary,
                          boxShadow: model.isLoadedInRam
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFF10B981),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        model.isLoadedInRam
                            ? 'In RAM (${model.formattedRamUsage})'
                            : isDownloading
                                ? 'Downloading ${(downloadProgress * 100).toStringAsFixed(0)}%'
                                : isDownloaded
                                    ? '✓ Downloaded'
                                    : 'Cloud Preset',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: model.isLoadedInRam || isDownloaded
                              ? const Color(0xFF10B981)
                              : isDownloading
                                  ? tokens.accent
                                  : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (model.description != null) ...[
              const SizedBox(height: 6),
              Text(
                model.description!,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Download Progress Bar (When Downloading)
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: downloadProgress > 0 ? downloadProgress : null,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    downloadStatus ?? 'Downloading weights to Downloads folder…',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.cancelDownload(model.id);
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent.shade100,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Download Button (When not yet downloaded on storage)
            if (!isDownloaded && !isDownloading) ...[
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton.icon(
                  icon: Icon(AppIcons.download, size: 14, color: tokens.accent),
                  label: Text(
                    '⬇ Download Model to Storage (${model.formattedSize})',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: tokens.accent.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: tokens.accent.withValues(alpha: 0.45),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await notifier.downloadModel(model);
                  },
                ),
              ),
            ],

            // Controls Row (When downloaded: Load/Unload, Set Active, Expand Config)
            if (isDownloaded) ...[
              Row(
                children: [
                  // Load / Unload Button
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        icon: state.loadingModelId == model.id
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: tokens.accent,
                                ),
                              )
                            : Icon(
                                model.isLoadedInRam
                                    ? AppIcons.stop
                                    : AppIcons.play,
                                size: 12,
                                color: model.isLoadedInRam
                                    ? Colors.orangeAccent
                                    : tokens.accent,
                              ),
                        label: Text(
                          state.loadingModelId == model.id
                              ? 'Loading RAM…'
                              : (model.isLoadedInRam
                                  ? 'Unload from RAM'
                                  : 'Load into RAM'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: model.isLoadedInRam
                                ? Colors.orangeAccent
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tokens.glassColor,
                          side: BorderSide(
                            color: model.isLoadedInRam
                                ? Colors.orangeAccent.withValues(alpha: 0.4)
                                : tokens.accent.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: state.isLoadingModel
                            ? null
                            : () async {
                                HapticFeedback.mediumImpact();
                                if (model.isLoadedInRam) {
                                  await notifier.unloadModelFromRam(model.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('ℹ️ ${model.name} unloaded from RAM.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  await notifier.loadModelIntoRam(model.id);
                                  if (mounted) {
                                    final err = ref.read(localModelStoreProvider).errorMessage;
                                    if (err == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ ${model.name} loaded into RAM! Ready to use.'),
                                          backgroundColor: const Color(0xFF10B981),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('⚠️ $err'),
                                          backgroundColor: Colors.redAccent.shade700,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Set Active Button
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isActive
                            ? tokens.accent.withValues(alpha: 0.15)
                            : tokens.glassColor,
                        foregroundColor: isActive
                            ? tokens.accent
                            : tokens.textSecondary,
                        side: BorderSide(
                          color: isActive
                              ? tokens.accent.withValues(alpha: 0.5)
                              : tokens.glassBorder,
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        notifier.setActiveModel(model.id);
                      },
                      child: Text(
                        isActive ? 'Active' : 'Select',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),

                // Settings Accordion Toggle
                Material(
                  color: tokens.glassColor,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(tokens.radiusSm),
                    onTap: () {
                      setState(() {
                        _expandedModelId =
                            isExpanded ? null : model.id;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: tokens.glassBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        isExpanded
                            ? AppIcons.chevronUp
                            : AppIcons.sliders,
                        size: 14,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

            // Expandable Parameter Settings
            if (isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Model Type Toggle (Chat LLM vs Image Model)
              Row(
                children: [
                  Text(
                    'Model Role:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<LocalModelType>(
                    segments: const [
                      ButtonSegment(
                        value: LocalModelType.chatGguf,
                        label: Text('Chat', style: TextStyle(fontSize: 10)),
                        icon: Icon(AppIcons.messageSquare, size: 11),
                      ),
                      ButtonSegment(
                        value: LocalModelType.uncensoredGguf,
                        label:
                            Text('Uncensored', style: TextStyle(fontSize: 10)),
                        icon: Icon(AppIcons.zap, size: 11),
                      ),
                      ButtonSegment(
                        value: LocalModelType.imageModel,
                        label: Text('Image', style: TextStyle(fontSize: 10)),
                        icon: Icon(AppIcons.image, size: 11),
                      ),
                    ],
                    selected: {model.type},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        notifier.setModelType(model.id, set.first);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chat Specific Settings
              if (model.type == LocalModelType.chatGguf ||
                  model.type == LocalModelType.uncensoredGguf) ...[
                Row(
                  children: [
                    Text(
                      'Context Window: ${model.contextSize} tokens',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: model.contextSize,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 2048, child: Text('2048')),
                        DropdownMenuItem(value: 4096, child: Text('4096')),
                        DropdownMenuItem(value: 8192, child: Text('8192')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateModelConfig(
                            model.id,
                            contextSize: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'CPU Threads: ${model.threads}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: model.threads,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 threads')),
                        DropdownMenuItem(value: 4, child: Text('4 threads')),
                        DropdownMenuItem(value: 6, child: Text('6 threads')),
                        DropdownMenuItem(value: 8, child: Text('8 threads')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateModelConfig(
                            model.id,
                            threads: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'GPU Layers: ${model.gpuLayers}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: model.gpuLayers,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('CPU (0)')),
                        DropdownMenuItem(value: 8, child: Text('8 Layers')),
                        DropdownMenuItem(value: 16, child: Text('16 Layers')),
                        DropdownMenuItem(value: 24, child: Text('24 Layers')),
                        DropdownMenuItem(value: 32, child: Text('32 Layers')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateModelConfig(
                            model.id,
                            gpuLayers: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],

              // Image Generation Specific Settings
              if (model.type == LocalModelType.imageModel) ...[
                Row(
                  children: [
                    Text(
                      'Diffusion Steps: ${model.steps}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: model.steps,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10 (Fast)')),
                        DropdownMenuItem(value: 20, child: Text('20 (Balanced)')),
                        DropdownMenuItem(value: 30, child: Text('30 (High)')),
                        DropdownMenuItem(value: 50, child: Text('50 (Ultra)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateImageParams(
                            model.id,
                            steps: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Aspect Ratio:',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: model.aspectRatio,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: '1:1', child: Text('1:1 Square')),
                        DropdownMenuItem(value: '16:9', child: Text('16:9 Landscape')),
                        DropdownMenuItem(value: '9:16', child: Text('9:16 Portrait')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateImageParams(
                            model.id,
                            aspectRatio: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Sampler: ${model.sampler}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: model.sampler,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'Euler A', child: Text('Euler A')),
                        DropdownMenuItem(value: 'DPM++ 2M', child: Text('DPM++ 2M')),
                        DropdownMenuItem(value: 'DDIM', child: Text('DDIM')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.updateImageParams(
                            model.id,
                            sampler: val,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Delete Model Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: Icon(AppIcons.trash,
                      size: 13, color: Colors.redAccent),
                  label: const Text(
                    'Remove Model',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                  onPressed: () {
                    notifier.deleteModel(model.id);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
    String text,
    dynamic tokens, {
    Color? color,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor ?? tokens.glassBorder.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color ?? tokens.textSecondary,
        ),
      ),
    );
  }
}
