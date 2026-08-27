import 'dart:io';

enum LocalModelType { chatGguf, uncensoredGguf, imageModel }

class LocalModelInfo {
  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileSizeBytes,
    required this.type,
    required this.quantization,
    this.downloadUrl,
    this.description,
    this.isLoadedInRam = false,
    this.ramUsageMb = 0,
    this.contextSize = 2048,
    this.threads = 4,
    this.gpuLayers = 0,
    this.steps = 20,
    this.cfgScale = 7.0,
    this.aspectRatio = '1:1',
    this.sampler = 'Euler A',
    this.negativePrompt = 'low quality, blurry, distorted, watermark',
    this.isDefault = false,
    required this.importedAt,
  });

  final String id;
  final String name;
  final String filePath;
  final int fileSizeBytes;
  final LocalModelType type;
  final String quantization;
  final String? downloadUrl;
  final String? description;
  final bool isLoadedInRam;
  final double ramUsageMb;
  final int contextSize;
  final int threads;
  final int gpuLayers;

  // Local Image Model parameters
  final int steps;
  final double cfgScale;
  final String aspectRatio;
  final String sampler;
  final String negativePrompt;

  final bool isDefault;
  final DateTime importedAt;

  bool get isUncensored =>
      type == LocalModelType.uncensoredGguf ||
      name.toLowerCase().contains('heretic') ||
      name.toLowerCase().contains('abliterated') ||
      name.toLowerCase().contains('uncensored');

  bool get isDownloaded {
    try {
      final f = File(filePath);
      if (f.existsSync() && f.lengthSync() > 0) return true;
      final dlFile = File('/storage/emulated/0/Download/$name');
      if (dlFile.existsSync() && dlFile.lengthSync() > 0) return true;
    } catch (_) {}
    return false;
  }

  String get effectiveFilePath {
    try {
      final f = File(filePath);
      if (f.existsSync()) return filePath;
      final dlFile = File('/storage/emulated/0/Download/$name');
      if (dlFile.existsSync()) return dlFile.path;
    } catch (_) {}
    return filePath;
  }

  String get formattedSize {
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedRamUsage {
    if (ramUsageMb >= 1024) {
      return '${(ramUsageMb / 1024).toStringAsFixed(2)} GB RAM';
    }
    return '${ramUsageMb.toStringAsFixed(0)} MB RAM';
  }

  LocalModelInfo copyWith({
    String? id,
    String? name,
    String? filePath,
    int? fileSizeBytes,
    LocalModelType? type,
    String? quantization,
    String? downloadUrl,
    String? description,
    bool? isLoadedInRam,
    double? ramUsageMb,
    int? contextSize,
    int? threads,
    int? gpuLayers,
    int? steps,
    double? cfgScale,
    String? aspectRatio,
    String? sampler,
    String? negativePrompt,
    bool? isDefault,
    DateTime? importedAt,
  }) =>
      LocalModelInfo(
        id: id ?? this.id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        type: type ?? this.type,
        quantization: quantization ?? this.quantization,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        description: description ?? this.description,
        isLoadedInRam: isLoadedInRam ?? this.isLoadedInRam,
        ramUsageMb: ramUsageMb ?? this.ramUsageMb,
        contextSize: contextSize ?? this.contextSize,
        threads: threads ?? this.threads,
        gpuLayers: gpuLayers ?? this.gpuLayers,
        steps: steps ?? this.steps,
        cfgScale: cfgScale ?? this.cfgScale,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        sampler: sampler ?? this.sampler,
        negativePrompt: negativePrompt ?? this.negativePrompt,
        isDefault: isDefault ?? this.isDefault,
        importedAt: importedAt ?? this.importedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'type': type.name,
        'quantization': quantization,
        'downloadUrl': downloadUrl,
        'description': description,
        'isLoadedInRam': isLoadedInRam,
        'ramUsageMb': ramUsageMb,
        'contextSize': contextSize,
        'threads': threads,
        'gpuLayers': gpuLayers,
        'steps': steps,
        'cfgScale': cfgScale,
        'aspectRatio': aspectRatio,
        'sampler': sampler,
        'negativePrompt': negativePrompt,
        'isDefault': isDefault,
        'importedAt': importedAt.toIso8601String(),
      };

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) => LocalModelInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String,
        fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
        type: LocalModelType.values.byName(
          json['type'] as String? ?? 'chatGguf',
        ),
        quantization: json['quantization'] as String? ?? 'Q4_K_M',
        downloadUrl: json['downloadUrl'] as String?,
        description: json['description'] as String?,
        isLoadedInRam: json['isLoadedInRam'] as bool? ?? false,
        ramUsageMb: (json['ramUsageMb'] as num?)?.toDouble() ?? 0.0,
        contextSize: json['contextSize'] as int? ?? 2048,
        threads: json['threads'] as int? ?? 4,
        gpuLayers: json['gpuLayers'] as int? ?? 0,
        steps: json['steps'] as int? ?? 20,
        cfgScale: (json['cfgScale'] as num?)?.toDouble() ?? 7.0,
        aspectRatio: json['aspectRatio'] as String? ?? '1:1',
        sampler: json['sampler'] as String? ?? 'Euler A',
        negativePrompt: json['negativePrompt'] as String? ??
            'low quality, blurry, distorted, watermark',
        isDefault: json['isDefault'] as bool? ?? false,
        importedAt: json['importedAt'] != null
            ? DateTime.tryParse(json['importedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
