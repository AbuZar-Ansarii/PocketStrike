import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketstrike/core/services/notification_service.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/local_models/data/local_model_engine.dart';
import 'package:pocketstrike/features/local_models/data/local_model_info.dart';
import 'package:uuid/uuid.dart';

class LocalModelState {
  const LocalModelState({
    this.models = const [],
    this.activeModelId,
    this.isLoadingModel = false,
    this.loadingModelId,
    this.downloadProgress = const {},
    this.downloadingModelId,
    this.downloadStatus = const {},
    this.totalDeviceRamGb = 8.0,
    this.errorMessage,
  });

  final List<LocalModelInfo> models;
  final String? activeModelId;
  final bool isLoadingModel;
  final String? loadingModelId;
  final Map<String, double> downloadProgress;
  final String? downloadingModelId;
  final Map<String, String> downloadStatus;
  final double totalDeviceRamGb;
  final String? errorMessage;

  bool isDownloading(String modelId) => downloadingModelId == modelId;
  double getProgress(String modelId) => downloadProgress[modelId] ?? 0.0;
  String? getStatus(String modelId) => downloadStatus[modelId];

  LocalModelInfo? get activeModel {
    if (activeModelId == null) {
      return models.where((m) => m.isLoadedInRam).firstOrNull ??
          models.where((m) => m.isDownloaded).firstOrNull ??
          models.firstOrNull;
    }
    return models.where((m) => m.id == activeModelId).firstOrNull;
  }

  double get totalAllocatedRamMb {
    var total = 0.0;
    for (final m in models) {
      if (m.isLoadedInRam) total += m.ramUsageMb;
    }
    return total;
  }

  LocalModelState copyWith({
    List<LocalModelInfo>? models,
    String? activeModelId,
    bool? isLoadingModel,
    String? loadingModelId,
    Map<String, double>? downloadProgress,
    String? downloadingModelId,
    Map<String, String>? downloadStatus,
    double? totalDeviceRamGb,
    String? errorMessage,
    bool clearActiveModel = false,
    bool clearLoadingModelId = false,
    bool clearDownloadingId = false,
    bool clearError = false,
  }) =>
      LocalModelState(
        models: models ?? this.models,
        activeModelId: clearActiveModel
            ? null
            : (activeModelId ?? this.activeModelId),
        isLoadingModel: isLoadingModel ?? this.isLoadingModel,
        loadingModelId: clearLoadingModelId
            ? null
            : (loadingModelId ?? this.loadingModelId),
        downloadProgress: downloadProgress ?? this.downloadProgress,
        downloadingModelId: clearDownloadingId
            ? null
            : (downloadingModelId ?? this.downloadingModelId),
        downloadStatus: downloadStatus ?? this.downloadStatus,
        totalDeviceRamGb: totalDeviceRamGb ?? this.totalDeviceRamGb,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

final localModelStoreProvider =
    NotifierProvider<LocalModelStoreNotifier, LocalModelState>(
        LocalModelStoreNotifier.new);

class LocalModelStoreNotifier extends Notifier<LocalModelState> {
  static const _kLocalModelsKey = 'pocketstrike_local_models_json';
  static const _kActiveLocalModelIdKey = 'pocketstrike_active_local_model_id';
  static const _uuid = Uuid();
  final Map<String, CancelToken> _cancelTokens = {};

  static List<LocalModelInfo> get defaultPresetModels => [
        // ==================== 🔥 UNCENSORED & ABLITERATED SLMS ====================
        LocalModelInfo(
          id: 'preset_smollm2_135m_uncensored',
          name: 'SmolLM2-135M-Instruct-heretic.Q4_K_M.gguf',
          filePath: '/storage/emulated/0/Download/SmolLM2-135M-Instruct-heretic.Q4_K_M.gguf',
          downloadUrl: 'https://huggingface.co/mradermacher/SmolLM2-135M-Instruct-heretic-GGUF/resolve/main/SmolLM2-135M-Instruct-heretic.Q4_K_M.gguf',
          fileSizeBytes: 105455104, // ~100 MB
          type: LocalModelType.uncensoredGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 150,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: '🔥 Uncensored & abliterated 135M SLM (100MB). Complete freedom with near-zero RAM footprint.',
          isDefault: true,
          importedAt: DateTime.now(),
        ),

        LocalModelInfo(
          id: 'preset_smollm2_360m_uncensored',
          name: 'SmolLM2-360M-Instruct-Heretic.Q4_K_M.gguf',
          filePath: '/storage/emulated/0/Download/SmolLM2-360M-Instruct-Heretic.Q4_K_M.gguf',
          downloadUrl: 'https://huggingface.co/mradermacher/SmolLM2-360M-Instruct-Heretic-GGUF/resolve/main/SmolLM2-360M-Instruct-Heretic.Q4_K_M.gguf',
          fileSizeBytes: 270591936, // ~258 MB
          type: LocalModelType.uncensoredGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 350,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: '🔥 Uncensored 360M parameter powerhouse. Higher reasoning without guardrail refusals.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        LocalModelInfo(
          id: 'preset_llama_1b_uncensored',
          name: 'abliterated-llama-3.2-1b-instruct-q4_k_m.gguf',
          filePath: '/storage/emulated/0/Download/abliterated-llama-3.2-1b-instruct-q4_k_m.gguf',
          downloadUrl: 'https://huggingface.co/ElectricLMA/Abliterated-Llama-3.2-1B-Instruct-Q4_K_M-GGUF/resolve/main/abliterated-llama-3.2-1b-instruct-q4_k_m.gguf',
          fileSizeBytes: 807690720, // ~770 MB
          type: LocalModelType.uncensoredGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 950,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: '🔥 Abliterated Meta Llama 3.2 1B. Fully uncensored instruction-following and creative tasks.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        // ==================== 💬 STANDARD CHAT & REASONING SLMS ====================
        LocalModelInfo(
          id: 'preset_qwen25_05b',
          name: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
          filePath: '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          fileSizeBytes: 491400032, // ~468 MB
          type: LocalModelType.chatGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 450,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: 'Compact 0.5B model with exceptional reasoning & multilingual abilities.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        LocalModelInfo(
          id: 'preset_llama_32_1b',
          name: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          filePath: '/storage/emulated/0/Download/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          fileSizeBytes: 807694464, // ~770 MB
          type: LocalModelType.chatGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 950,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: 'Official Meta 1B model. High quality reasoning, coding, and formatting.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        LocalModelInfo(
          id: 'preset_deepseek_r1',
          name: 'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
          filePath: '/storage/emulated/0/Download/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
          downloadUrl: 'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
          fileSizeBytes: 1117320800, // ~1.06 GB
          type: LocalModelType.chatGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 1420,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: 'Open reasoning model distilled with deep chain-of-thought logic.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        LocalModelInfo(
          id: 'preset_llama_32',
          name: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          filePath: '/storage/emulated/0/Download/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          fileSizeBytes: 2013265920, // ~1.9 GB
          type: LocalModelType.chatGguf,
          quantization: 'Q4_K_M',
          isLoadedInRam: false,
          ramUsageMb: 2350,
          contextSize: 2048,
          threads: 4,
          gpuLayers: 0,
          description: 'Full 3B powerhouse for advanced reasoning, creative prose, and tool execution.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),

        // ==================== 🎨 IMAGE GENERATION MODEL ====================
        LocalModelInfo(
          id: 'preset_sd_turbo',
          name: 'SD-Turbo-Image-Gen.gguf',
          filePath: '/storage/emulated/0/Download/SD-Turbo-Image-Gen.gguf',
          fileSizeBytes: 1717986918,
          type: LocalModelType.imageModel,
          quantization: 'FP16',
          isLoadedInRam: false,
          ramUsageMb: 1800,
          contextSize: 512,
          threads: 4,
          gpuLayers: 0,
          description: 'Neural image generator for on-device and local procedural image synthesis.',
          isDefault: false,
          importedAt: DateTime.now(),
        ),
      ];

  @override
  LocalModelState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final rawJson = prefs.getString(_kLocalModelsKey);
    final activeId = prefs.getString(_kActiveLocalModelIdKey);

    List<LocalModelInfo> models = [];
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final list = jsonDecode(rawJson) as List;
        models = list
            .map((item) => LocalModelInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Auto-update presets with working download URLs
    final presetMap = {for (final p in defaultPresetModels) p.id: p};
    models = models.map((m) {
      if (presetMap.containsKey(m.id)) {
        final preset = presetMap[m.id]!;
        return m.copyWith(
          name: preset.name,
          downloadUrl: preset.downloadUrl,
          fileSizeBytes: preset.fileSizeBytes,
          quantization: preset.quantization,
          description: preset.description,
          type: preset.type,
        );
      }
      return m;
    }).toList();

    // Merge missing default presets
    final existingIds = models.map((m) => m.id).toSet();
    final missingPresets = defaultPresetModels
        .where((preset) => !existingIds.contains(preset.id))
        .toList();

    if (missingPresets.isNotEmpty || models.isEmpty) {
      models = [...missingPresets, ...models];
      _saveModels(models);
    }

    return LocalModelState(
      models: models,
      activeModelId: activeId ??
          models.where((m) => m.isLoadedInRam).firstOrNull?.id ??
          models.where((m) => m.isDownloaded).firstOrNull?.id ??
          models.firstOrNull?.id,
      totalDeviceRamGb: 8.0,
    );
  }

  Future<void> _saveModels(List<LocalModelInfo> models) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final rawJson = jsonEncode(models.map((m) => m.toJson()).toList());
    await prefs.setString(_kLocalModelsKey, rawJson);
  }

  /// Imports a local GGUF / image model file from storage.
  Future<LocalModelInfo?> importModelFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty) return null;
      final file = files.first;
      final path = file.path;
      if (path == null) return null;

      final name = file.name;
      int size = 0;
      try {
        size = File(path).lengthSync();
      } catch (_) {}

      // Detect model type & quantization
      final lowerName = name.toLowerCase();
      final isImage = lowerName.endsWith('.safetensors') ||
          lowerName.endsWith('.ckpt') ||
          lowerName.endsWith('.pt') ||
          lowerName.endsWith('.bin') ||
          lowerName.contains('sd') ||
          lowerName.contains('diffusion') ||
          lowerName.contains('flux') ||
          lowerName.contains('realistic') ||
          lowerName.contains('cyber') ||
          lowerName.contains('vision') ||
          lowerName.contains('checkpoint') ||
          lowerName.contains('lora') ||
          lowerName.contains('image');
      final type = isImage ? LocalModelType.imageModel : LocalModelType.chatGguf;

      var quant = 'Q4_K_M';
      final nameUpper = name.toUpperCase();
      if (nameUpper.contains('Q4_K_M')) {
        quant = 'Q4_K_M';
      } else if (nameUpper.contains('Q4_0')) {
        quant = 'Q4_0';
      } else if (nameUpper.contains('Q5_K_M')) {
        quant = 'Q5_K_M';
      } else if (nameUpper.contains('Q8_0')) {
        quant = 'Q8_0';
      } else if (nameUpper.contains('FP16') || nameUpper.contains('F16')) {
        quant = 'FP16';
      } else if (nameUpper.contains('Q2_K')) {
        quant = 'Q2_K';
      }

      final model = LocalModelInfo(
        id: _uuid.v4(),
        name: name,
        filePath: path,
        fileSizeBytes: size,
        type: type,
        quantization: quant,
        isLoadedInRam: false,
        ramUsageMb: (size / (1024 * 1024) * 1.15),
        contextSize: 2048,
        threads: 4,
        gpuLayers: 16,
        isDefault: state.models.isEmpty,
        importedAt: DateTime.now(),
      );

      final updated = [...state.models, model];
      state = state.copyWith(models: updated);
      await _saveModels(updated);
      return model;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to import model: $e');
      return null;
    }
  }

  /// Downloads a GGUF model directly from HuggingFace to storage.
  Future<void> downloadModel(LocalModelInfo model) async {
    final url = model.downloadUrl;
    if (url == null || url.isEmpty) {
      state = state.copyWith(
        errorMessage: 'No direct download URL available for "${model.name}".',
      );
      return;
    }

    if (state.downloadingModelId == model.id) return;

    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;

    state = state.copyWith(
      downloadingModelId: model.id,
      downloadProgress: {...state.downloadProgress, model.id: 0.01},
      downloadStatus: {...state.downloadStatus, model.id: 'Connecting…'},
      clearError: true,
    );

    final notifService = ref.read(notificationServiceProvider);
    final notifId = model.name.hashCode.abs() % 100000;

    // Target storage directory (Android Downloads or App documents)
    String targetPath = '/storage/emulated/0/Download/${model.name}';
    bool canWriteExternal = false;
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }
      final probe = File(
          '/storage/emulated/0/Download/.probe_${DateTime.now().millisecondsSinceEpoch}');
      probe.writeAsStringSync('test');
      probe.deleteSync();
      canWriteExternal = true;
    } catch (_) {
      canWriteExternal = false;
    }

    if (!canWriteExternal) {
      final docDir = await getApplicationDocumentsDirectory();
      targetPath = '${docDir.path}/${model.name}';
    }

    final tempPath = '$targetPath.part';

    try {
      final dio = Dio(
        BaseOptions(
          followRedirects: true,
          maxRedirects: 10,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 60),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 15; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            'Accept': '*/*',
          },
        ),
      );
      int lastNotifUpdate = 0;

      await dio.download(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            total = model.fileSizeBytes > 0
                ? model.fileSizeBytes
                : 150 * 1024 * 1024;
          }
          final progress = (received / total).clamp(0.0, 1.0);
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
          final statusStr =
              '${(progress * 100).toStringAsFixed(0)}% • $recMb MB / $totMb MB';

          state = state.copyWith(
            downloadProgress: {...state.downloadProgress, model.id: progress},
            downloadStatus: {...state.downloadStatus, model.id: statusStr},
          );

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotifUpdate > 800 || progress >= 0.99) {
            lastNotifUpdate = now;
            notifService.showDownloadProgress(
              id: notifId,
              title: 'PocketStrike: Downloading ${model.name}',
              body: statusStr,
              progress: (progress * 100).toInt(),
              maxProgress: 100,
              ongoing: true,
            );
          }
        },
      );

      // Finalize file
      final tempFile = File(tempPath);
      if (tempFile.existsSync()) {
        final finalFile = File(targetPath);
        if (finalFile.existsSync()) finalFile.deleteSync();
        tempFile.renameSync(targetPath);
      }

      // Success notification
      await notifService.showNotification(
        id: notifId,
        title: '✅ Model Download Complete',
        body: '${model.name} saved to Downloads folder! Tap to load into RAM.',
      );

      int fileSize = model.fileSizeBytes;
      try {
        final f = File(targetPath);
        if (f.existsSync()) fileSize = f.lengthSync();
      } catch (_) {}

      final updated = state.models.map((m) {
        if (m.id == model.id) {
          return m.copyWith(
            filePath: targetPath,
            fileSizeBytes: fileSize > 0 ? fileSize : m.fileSizeBytes,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(
        models: updated,
        clearDownloadingId: true,
        downloadProgress: {...state.downloadProgress, model.id: 1.0},
        downloadStatus: {...state.downloadStatus, model.id: 'Downloaded'},
      );

      await _saveModels(updated);
    } catch (e) {
      if (cancelToken.isCancelled) {
        state = state.copyWith(
          clearDownloadingId: true,
          downloadStatus: {...state.downloadStatus, model.id: 'Cancelled'},
        );
      } else {
        state = state.copyWith(
          clearDownloadingId: true,
          errorMessage: 'Download failed: $e',
          downloadStatus: {...state.downloadStatus, model.id: 'Failed'},
        );
      }
      try {
        final tempFile = File(tempPath);
        if (tempFile.existsSync()) tempFile.deleteSync();
      } catch (_) {}
      await notifService.cancelNotification(notifId);
    } finally {
      _cancelTokens.remove(model.id);
    }
  }

  /// Cancels an in-progress model download.
  void cancelDownload(String modelId) {
    final token = _cancelTokens[modelId];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
  }

  /// Loads the selected model into RAM memory.
  Future<void> loadModelIntoRam(String modelId) async {
    state = state.copyWith(
      isLoadingModel: true,
      loadingModelId: modelId,
      clearError: true,
    );

    final targetModel = state.models.where((m) => m.id == modelId).firstOrNull;
    if (targetModel == null) {
      state = state.copyWith(
        isLoadingModel: false,
        clearLoadingModelId: true,
        errorMessage: 'Model configuration not found.',
      );
      return;
    }

    try {
      final effectivePath = targetModel.effectiveFilePath;
      final isImageFile = targetModel.type == LocalModelType.imageModel ||
          effectivePath.toLowerCase().endsWith('.safetensors') ||
          effectivePath.toLowerCase().endsWith('.ckpt') ||
          effectivePath.toLowerCase().endsWith('.pt') ||
          effectivePath.toLowerCase().endsWith('.bin') ||
          effectivePath.toLowerCase().contains('realistic') ||
          effectivePath.toLowerCase().contains('diffusion');

      if (!isImageFile &&
          (targetModel.type == LocalModelType.chatGguf ||
              targetModel.type == LocalModelType.uncensoredGguf)) {
        final file = File(effectivePath);
        if (!file.existsSync()) {
          state = state.copyWith(
            isLoadingModel: false,
            clearLoadingModelId: true,
            errorMessage:
                'GGUF file not found at "$effectivePath". Please download or import the model first.',
          );
          return;
        }

        final success = await LocalLlamaNativeService.instance.loadModel(
          targetModel.copyWith(filePath: effectivePath),
        );
        if (!success) {
          state = state.copyWith(
            isLoadingModel: false,
            clearLoadingModelId: true,
            errorMessage:
                'Failed to initialize GGUF model weights into RAM. Ensure file is a valid .gguf format.',
          );
          return;
        }
      } else {
        // Image diffusion model loading simulation
        await Future.delayed(const Duration(milliseconds: 600));
      }

      final updated = state.models.map((m) {
        if (m.id == modelId) {
          var realSize = m.fileSizeBytes;
          try {
            final f = File(effectivePath);
            if (f.existsSync()) realSize = f.lengthSync();
          } catch (_) {}
          final ramUsage = realSize > 0 ? (realSize / (1024 * 1024) * 1.15) : m.ramUsageMb;
          return m.copyWith(
            filePath: effectivePath,
            type: isImageFile ? LocalModelType.imageModel : m.type,
            isLoadedInRam: true,
            ramUsageMb: ramUsage > 0 ? ramUsage : m.ramUsageMb,
            fileSizeBytes: realSize > 0 ? realSize : m.fileSizeBytes,
          );
        }
        return m;
      }).toList();

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_kActiveLocalModelIdKey, modelId);

      state = state.copyWith(
        models: updated,
        activeModelId: modelId,
        isLoadingModel: false,
        clearLoadingModelId: true,
      );
      await _saveModels(updated);
    } catch (e) {
      state = state.copyWith(
        isLoadingModel: false,
        clearLoadingModelId: true,
        errorMessage: 'Error loading model into RAM: $e',
      );
    }
  }

  /// Unloads the model from RAM memory.
  Future<void> unloadModelFromRam(String modelId) async {
    try {
      await LocalLlamaNativeService.instance.unload();
    } catch (_) {}

    final updated = state.models.map((m) {
      if (m.id == modelId) {
        return m.copyWith(isLoadedInRam: false);
      }
      return m;
    }).toList();

    state = state.copyWith(models: updated);
    await _saveModels(updated);
  }

  /// Deletes an imported model from the list.
  Future<void> deleteModel(String modelId) async {
    if (state.activeModelId == modelId) {
      try {
        await LocalLlamaNativeService.instance.unload();
      } catch (_) {}
    }

    final updated = state.models.where((m) => m.id != modelId).toList();
    final newActiveId = state.activeModelId == modelId
        ? (updated.firstOrNull?.id)
        : state.activeModelId;

    state = state.copyWith(
      models: updated,
      activeModelId: newActiveId,
      clearActiveModel: newActiveId == null,
    );
    await _saveModels(updated);
  }

  /// Updates parameters for a model (Context size, CPU threads, GPU layers).
  Future<void> updateModelConfig(
    String modelId, {
    int? contextSize,
    int? threads,
    int? gpuLayers,
  }) async {
    final updated = state.models.map((m) {
      if (m.id == modelId) {
        return m.copyWith(
          contextSize: contextSize ?? m.contextSize,
          threads: threads ?? m.threads,
          gpuLayers: gpuLayers ?? m.gpuLayers,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(models: updated);
    await _saveModels(updated);
  }

  /// Sets model type (Chat LLM vs Local Image Model).
  Future<void> setModelType(String modelId, LocalModelType type) async {
    final updated = state.models.map((m) {
      if (m.id == modelId) {
        return m.copyWith(type: type);
      }
      return m;
    }).toList();

    state = state.copyWith(models: updated);
    await _saveModels(updated);
  }

  /// Switches to image generation mode.
  Future<void> switchToImageMode() async {
    final existingImageModel = state.models
        .where((m) => m.type == LocalModelType.imageModel)
        .firstOrNull;
    if (existingImageModel != null) {
      setActiveModel(existingImageModel.id);
    } else if (state.activeModel != null) {
      await setModelType(state.activeModel!.id, LocalModelType.imageModel);
    }
  }

  /// Switches to chat LLM mode.
  Future<void> switchToChatMode() async {
    final existingChatModel = state.models
        .where((m) => m.type == LocalModelType.chatGguf)
        .firstOrNull;
    if (existingChatModel != null) {
      setActiveModel(existingChatModel.id);
    } else if (state.activeModel != null) {
      await setModelType(state.activeModel!.id, LocalModelType.chatGguf);
    }
  }

  /// Updates image generation parameters for the active or preset model.
  Future<void> updateActiveOrPresetImageParams({
    int? steps,
    double? cfgScale,
    String? aspectRatio,
    String? sampler,
    String? negativePrompt,
  }) async {
    final active = state.activeModel;
    if (active != null) {
      await updateImageParams(
        active.id,
        steps: steps,
        cfgScale: cfgScale,
        aspectRatio: aspectRatio,
        sampler: sampler,
        negativePrompt: negativePrompt,
      );
    } else if (state.models.isNotEmpty) {
      await updateImageParams(
        state.models.first.id,
        steps: steps,
        cfgScale: cfgScale,
        aspectRatio: aspectRatio,
        sampler: sampler,
        negativePrompt: negativePrompt,
      );
    }
  }

  /// Updates image generation parameters for an image model.
  Future<void> updateImageParams(
    String modelId, {
    int? steps,
    double? cfgScale,
    String? aspectRatio,
    String? sampler,
    String? negativePrompt,
  }) async {
    final updated = state.models.map((m) {
      if (m.id == modelId) {
        return m.copyWith(
          steps: steps ?? m.steps,
          cfgScale: cfgScale ?? m.cfgScale,
          aspectRatio: aspectRatio ?? m.aspectRatio,
          sampler: sampler ?? m.sampler,
          negativePrompt: negativePrompt ?? m.negativePrompt,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(models: updated);
    await _saveModels(updated);
  }

  void setActiveModel(String modelId) {
    state = state.copyWith(activeModelId: modelId);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kActiveLocalModelIdKey, modelId);
  }
}
