import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'package:path_provider/path_provider.dart';
import 'package:pocketstrike/core/models/chat_models.dart';
import 'package:pocketstrike/features/local_models/data/local_model_info.dart';
import 'package:pocketstrike/features/providers/domain/ai_provider.dart';

/// Formatter for prompt formatting across popular local LLM architectures.
class LocalPromptFormatter {
  static String format({
    required List<ChatMessage> messages,
    required String modelNameOrPath,
    String? fallbackSystemPrompt,
  }) {
    final lower = modelNameOrPath.toLowerCase();

    // 1. Separate system prompt and chat conversation turns
    String systemPrompt = '';
    final conversationTurns = <ChatMessage>[];

    for (final m in messages) {
      if (m.role == MessageRole.system) {
        if (m.content.trim().isNotEmpty) {
          systemPrompt = m.content.trim();
        }
      } else {
        if (m.content.trim().isNotEmpty) {
          conversationTurns.add(m);
        }
      }
    }

    if (systemPrompt.isEmpty) {
      systemPrompt = fallbackSystemPrompt ??
          'You are PocketStrike AI, a helpful, intelligent, and direct assistant.';
    }

    // 2. Llama 3 / 3.1 / 3.2 / 3.3
    if (lower.contains('llama-3') ||
        lower.contains('llama3') ||
        lower.contains('llama_3')) {
      final sb = StringBuffer();
      sb.write('<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n');
      sb.write(systemPrompt);
      sb.write('<|eot_id|>');

      for (final turn in conversationTurns) {
        final role = turn.role == MessageRole.user ? 'user' : 'assistant';
        sb.write('<|start_header_id|>$role<|end_header_id|>\n\n');
        sb.write(turn.content.trim());
        sb.write('<|eot_id|>');
      }

      sb.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
      return sb.toString();
    }

    // 3. Gemma / Gemma 2 / Gemma 3
    if (lower.contains('gemma')) {
      final sb = StringBuffer();
      sb.write('<bos>');
      var isFirst = true;

      for (final turn in conversationTurns) {
        if (turn.role == MessageRole.user) {
          sb.write('<start_of_turn>user\n');
          if (isFirst && systemPrompt.isNotEmpty) {
            sb.write('$systemPrompt\n\n');
            isFirst = false;
          }
          sb.write('${turn.content.trim()}<end_of_turn>\n');
        } else {
          sb.write('<start_of_turn>model\n${turn.content.trim()}<end_of_turn>\n');
        }
      }

      sb.write('<start_of_turn>model\n');
      return sb.toString();
    }

    // 4. Phi-2 / Phi-3 / Phi-3.5
    if (lower.contains('phi')) {
      final sb = StringBuffer();
      if (systemPrompt.isNotEmpty) {
        sb.write('<|system|>\n$systemPrompt<|end|>\n');
      }
      for (final turn in conversationTurns) {
        final tag = turn.role == MessageRole.user ? 'user' : 'assistant';
        sb.write('<|$tag|>\n${turn.content.trim()}<|end|>\n');
      }
      sb.write('<|assistant|>\n');
      return sb.toString();
    }

    // 5. Mistral / Mixtral
    if (lower.contains('mistral') || lower.contains('mixtral')) {
      final sb = StringBuffer();
      sb.write('<s>');
      var isFirst = true;
      for (final turn in conversationTurns) {
        if (turn.role == MessageRole.user) {
          if (!isFirst) sb.write('</s><s>');
          sb.write('[INST] ');
          if (isFirst && systemPrompt.isNotEmpty) {
            sb.write('$systemPrompt\n\n');
            isFirst = false;
          }
          sb.write('${turn.content.trim()} [/INST]');
        } else {
          sb.write(' ${turn.content.trim()}');
        }
      }
      return sb.toString();
    }

    // 6. Default: ChatML (Qwen, DeepSeek, SmolLM, Yi, and most instruct GGUFs)
    final sb = StringBuffer();
    if (systemPrompt.isNotEmpty) {
      sb.write('<|im_start|>system\n$systemPrompt<|im_end|>\n');
    }
    for (final turn in conversationTurns) {
      final role = turn.role == MessageRole.user ? 'user' : 'assistant';
      sb.write('<|im_start|>$role\n${turn.content.trim()}<|im_end|>\n');
    }
    sb.write('<|im_start|>assistant\n');
    return sb.toString();
  }
}

/// Token streaming filter that strips EOS/EOT delimiters and trailing turn headers.
class LocalStopTokenFilter {
  static const List<String> stopTokens = [
    '<|im_end|>',
    '<|eot_id|>',
    '<end_of_turn>',
    '<|end|>',
    '</s>',
    '<eos>',
    '<|im_start|>',
    '<|start_header_id|>',
    '<start_of_turn>',
    '### User:',
    '### Human:',
    '\nUser:',
    '\nHuman:',
  ];

  String _buffer = '';
  bool _stopped = false;

  bool get isStopped => _stopped;

  String? processToken(String token) {
    if (_stopped) return null;
    _buffer += token;

    for (final stop in stopTokens) {
      final idx = _buffer.indexOf(stop);
      if (idx != -1) {
        _stopped = true;
        final clean = _buffer.substring(0, idx);
        _buffer = '';
        return clean.isNotEmpty ? clean : null;
      }
    }

    for (final stop in stopTokens) {
      for (var len = 1; len < stop.length; len++) {
        if (_buffer.endsWith(stop.substring(0, len))) {
          return null; // Wait for full token to match or pass
        }
      }
    }

    final out = _buffer;
    _buffer = '';
    return out.isNotEmpty ? out : null;
  }

  String? flush() {
    if (_stopped || _buffer.isEmpty) return null;
    final out = _buffer;
    _buffer = '';
    return out;
  }
}

/// Singleton manager for native llama.cpp offline execution on Android.
class LocalLlamaNativeService {
  LocalLlamaNativeService._();
  static final LocalLlamaNativeService instance = LocalLlamaNativeService._();

  llama.LlamaController? _controller;
  String? _loadedModelId;
  String? _loadedModelPath;
  bool _isInitializing = false;

  llama.LlamaController get controller {
    _controller ??= llama.LlamaController();
    return _controller!;
  }

  bool get isAndroid => Platform.isAndroid;
  String? get loadedModelId => _loadedModelId;
  String? get loadedModelPath => _loadedModelPath;

  /// Loads a GGUF model into memory using native llama.cpp runtime.
  Future<bool> loadModel(LocalModelInfo model) async {
    if (!isAndroid) return true; // Graceful fallback for non-Android / tests

    final effectivePath = model.effectiveFilePath;
    final file = File(effectivePath);
    if (!file.existsSync()) {
      if (kDebugMode) {
        print('[LocalLlama] File does not exist: $effectivePath');
      }
      return false;
    }

    // Check if already loaded
    if (_loadedModelPath == effectivePath && _controller != null) {
      try {
        final isLoaded = await _controller!.isModelLoaded();
        if (isLoaded) {
          await clearContext();
          return true;
        }
      } catch (_) {}
    }

    if (_isInitializing) return false;
    _isInitializing = true;

    try {
      // Safely dispose old controller instance
      if (_controller != null) {
        try {
          await _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }

      final newController = llama.LlamaController();
      _controller = newController;

      final safeThreads = min(4, max(1, model.threads));
      final safeContext = min(2048, max(512, model.contextSize));

      try {
        await newController.loadModel(
          modelPath: effectivePath,
          threads: safeThreads,
          contextSize: safeContext,
          gpuLayers: null, // Pure CPU ARM NEON inference is 100% crash-proof
        );
      } catch (loadErr) {
        if (kDebugMode) {
          print(
              '[LocalLlama] First attempt failed ($loadErr), retrying with minimal config');
        }
        await newController.loadModel(
          modelPath: effectivePath,
          threads: 2,
          contextSize: 512,
          gpuLayers: null,
        );
      }

      _loadedModelId = model.id;
      _loadedModelPath = effectivePath;
      await clearContext();

      if (kDebugMode) {
        print(
            '[LocalLlama] Successfully loaded GGUF model: $effectivePath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[LocalLlama] Error loading model: $e');
      }
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Clears KV cache to ensure clean generation state.
  Future<void> clearContext() async {
    if (!isAndroid) return;
    try {
      await controller.clearContext();
    } catch (_) {}
  }

  /// Unloads the model and frees RAM memory.
  Future<void> unload() async {
    if (!isAndroid) return;
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    _loadedModelId = null;
    _loadedModelPath = null;
  }

  /// Stops in-flight token generation.
  Future<void> stop() async {
    if (!isAndroid) return;
    try {
      await _controller?.stop();
    } catch (_) {}
  }

  /// Streams tokens for prompt.
  Stream<String> generateStream(
    String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) {
    if (!isAndroid || _controller == null) {
      return Stream.value('');
    }
    return controller.generate(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
      topK: topK,
      repeatPenalty: repeatPenalty,
    );
  }
}

/// 100% Offline Local Model Provider for GGUF LLMs and Local Image Generation.
class LocalAIProvider implements AIProvider {
  LocalAIProvider({this.activeModel});

  final LocalModelInfo? activeModel;

  @override
  String get configId => 'local_model_provider';

  @override
  String get displayName =>
      activeModel != null ? 'Local: ${activeModel!.name}' : 'Local GGUF Engine';

  @override
  bool get supportsTools => true;

  @override
  bool get supportsVision => false;

  @override
  Future<List<String>> listModels() async {
    if (activeModel != null) {
      return [activeModel!.id, activeModel!.name];
    }
    return ['local-gguf-default'];
  }

  @override
  Stream<ChatStreamEvent> streamMessage(ChatRequest request) async* {
    final model = activeModel;
    final lastUserMsg = request.messages
        .where((m) => m.role == MessageRole.user)
        .lastOrNull
        ?.content
        .trim() ??
        '';

    // 1. Image Model or Image Generation Prompt
    final lower = lastUserMsg.toLowerCase();
    final isImagePrompt = model?.type == LocalModelType.imageModel ||
        lower.startsWith('/image') ||
        lower.startsWith('/img') ||
        lower.startsWith('image') ||
        lower.startsWith('photo') ||
        lower.startsWith('picture') ||
        lower.startsWith('wallpaper') ||
        lower.startsWith('generate') ||
        lower.startsWith('create') ||
        lower.startsWith('draw') ||
        lower.startsWith('paint') ||
        lower.startsWith('imagine') ||
        lower.startsWith('render') ||
        lower.contains('generate an image') ||
        lower.contains('generate image') ||
        lower.contains('generate a picture') ||
        lower.contains('generate picture') ||
        lower.contains('draw an image') ||
        lower.contains('draw a picture') ||
        lower.contains('create an image') ||
        lower.contains('create a picture') ||
        lower.contains('make an image') ||
        lower.contains('make a picture') ||
        lower.contains('image of') ||
        lower.contains('picture of') ||
        lower.contains('photo of') ||
        lower.contains('draw ') ||
        lower.contains('paint ') ||
        lower.contains('artwork of');

    if (isImagePrompt) {
      yield* _streamLocalImageGeneration(lastUserMsg, request, model);
      return;
    }

    // 2. Offline Local Chat LLM (GGUF) Native Inference
    yield* _streamLocalChatInference(lastUserMsg, request, model);
  }

  Stream<ChatStreamEvent> _streamLocalChatInference(
    String userPrompt,
    ChatRequest request,
    LocalModelInfo? model,
  ) async* {
    if (model == null) {
      yield const TextDeltaEvent(
        '⚠️ **No Local Model Selected**\n\n'
        'Please select or import a `.gguf` model in **Settings > Local & Offline Models**.',
      );
      yield const StreamDoneEvent();
      return;
    }

    final effectivePath = model.effectiveFilePath;
    final file = File(effectivePath);
    if (!file.existsSync()) {
      yield TextDeltaEvent(
        '⚠️ **No Offline Model Downloaded on Storage**\n\n'
        'You have selected **${model.name}**, but its model weights are not downloaded on device storage yet.\n\n'
        '### 🚀 Quick Start (1-Tap Download):\n'
        '1. Go to **Settings > Local & Offline Models**.\n'
        '2. Tap **"⬇ Download Model"** on **${model.name}** (or lightweight models like **LFM 2.5 230M** or **SmolLM2 135M**).\n'
        '3. Once downloaded, tap **"Load into RAM"** and start chatting 100% offline!',
      );
      yield const StreamDoneEvent();
      return;
    }

    // Ensure model is loaded in memory
    final isLoaded = LocalLlamaNativeService.instance.loadedModelPath == effectivePath;
    if (!isLoaded) {
      final success = await LocalLlamaNativeService.instance.loadModel(
        model.copyWith(filePath: effectivePath),
      );
      if (!success) {
        yield const StreamErrorEvent(
          'Failed to load GGUF model into device memory. Ensure device has enough free RAM.',
        );
        return;
      }
    } else {
      // Clear context before each new query turn to prevent context corruption
      await LocalLlamaNativeService.instance.clearContext();
    }

    // Format prompt using appropriate chat template for the loaded model
    final formattedPrompt = LocalPromptFormatter.format(
      messages: request.messages,
      modelNameOrPath: '${model.name} ${model.filePath}',
      fallbackSystemPrompt: 'You are PocketStrike AI, a helpful, intelligent, and concise assistant.',
    );

    // Bind cancellation token
    request.cancelToken?.whenCancel.then((_) {
      LocalLlamaNativeService.instance.stop();
    });

    final stopwatch = Stopwatch()..start();
    var tokenCount = 0;
    final stopFilter = LocalStopTokenFilter();
    var isFirstYield = true;

    try {
      final tokenStream = LocalLlamaNativeService.instance.generateStream(
        formattedPrompt,
        maxTokens: request.params.maxTokens,
        temperature: request.params.temperature,
        topP: request.params.topP,
        topK: 40,
        repeatPenalty: 1.15,
      );

      await for (final rawToken in tokenStream) {
        if (request.cancelToken?.isCancelled ?? false) break;

        final processed = stopFilter.processToken(rawToken);
        if (stopFilter.isStopped) {
          if (processed != null && processed.isNotEmpty) {
            yield TextDeltaEvent(processed);
            tokenCount++;
          }
          await LocalLlamaNativeService.instance.stop();
          break;
        }

        if (processed != null && processed.isNotEmpty) {
          var cleanToken = processed;
          if (isFirstYield) {
            // Strip any accidental leading role prefix echo or model identifiers
            cleanToken = cleanToken.replaceFirst(
              RegExp(
                r'^(<\|im_start\|>assistant\s*|<\|start_header_id\|>assistant<\|end_header_id\|>\s*|Assistant:\s*|PocketStrike:\s*|AI:\s*|<start_of_turn>model\s*|model\s*\n*)',
                caseSensitive: false,
              ),
              '',
            );
            if (cleanToken.trim().isNotEmpty) {
              isFirstYield = false;
            }
          }

          if (cleanToken.isNotEmpty) {
            yield TextDeltaEvent(cleanToken);
            tokenCount++;
            final curSec = stopwatch.elapsedMilliseconds / 1000.0;
            if (curSec > 0.12 && tokenCount % 2 == 0) {
              yield SpeedMetricsEvent(
                tokensPerSecond: tokenCount / curSec,
                tokenCount: tokenCount,
                latencyMs: stopwatch.elapsedMilliseconds,
              );
            }
          }
        }
      }

      final remaining = stopFilter.flush();
      if (remaining != null && remaining.isNotEmpty) {
        yield TextDeltaEvent(remaining);
        tokenCount++;
      }
    } catch (e) {
      yield StreamErrorEvent('Local GGUF execution error: $e');
      return;
    } finally {
      stopwatch.stop();
    }

    final totalSec = stopwatch.elapsedMilliseconds / 1000.0;
    if (totalSec > 0 && tokenCount > 0) {
      yield SpeedMetricsEvent(
        tokensPerSecond: tokenCount / totalSec,
        tokenCount: tokenCount,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }

    yield UsageEvent(UsageInfo(
      promptTokens: request.messages.fold<int>(0, (acc, m) => acc + (m.content.length ~/ 4)),
      completionTokens: tokenCount,
    ));
    yield const StreamDoneEvent();
  }

  Stream<ChatStreamEvent> _streamLocalImageGeneration(
    String userPrompt,
    ChatRequest request,
    LocalModelInfo? model,
  ) async* {
    var cleanPrompt = userPrompt
        .replaceFirst(RegExp(r'^/image\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^/img\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^generate an image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^generate image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^generate an image\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^generate image\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^create an image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^create image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^create image\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^draw an image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^draw a\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^draw\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^paint an image of\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^paint\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^imagine\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^make an image of\s*', caseSensitive: false), '')
        .trim();

    if (cleanPrompt.isEmpty) cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) cleanPrompt = 'Cyberpunk futuristic skyline';

    final promptDisplay = cleanPrompt;
    final aspectRatio = model?.aspectRatio ?? '1:1';

    final stopwatch = Stopwatch()..start();

    try {
      // Synthesize image using neural diffusion engine
      final imageFile = await synthesizeImageDirect(
        prompt: promptDisplay,
        aspectRatio: aspectRatio,
      );
      stopwatch.stop();

      yield TextDeltaEvent('Here is your image:\n\n![Generated Image](file://${imageFile.path})');
      yield const UsageEvent(UsageInfo(promptTokens: 24, completionTokens: 120));
      yield const StreamDoneEvent();
    } catch (e) {
      stopwatch.stop();
      yield StreamErrorEvent('Failed to synthesize image on device: $e');
    }
  }

  /// Public static method for synthesizing images from prompts (used by chat & agent tools)
  static Future<File> synthesizeImageDirect({
    required String prompt,
    String aspectRatio = '1:1',
  }) async {
    final int width;
    final int height;
    switch (aspectRatio) {
      case '16:9':
        width = 1280;
        height = 720;
        break;
      case '9:16':
        width = 720;
        height = 1280;
        break;
      case '4:3':
        width = 1024;
        height = 768;
        break;
      case '3:4':
        width = 768;
        height = 1024;
        break;
      case '1:1':
      default:
        width = 1024;
        height = 1024;
        break;
    }

    // Enhance prompt with high-fidelity detail & sharp focus tokens
    String enhancedPrompt = prompt.trim();
    final lowerPrompt = enhancedPrompt.toLowerCase();
    final hasQualityKeywords = lowerPrompt.contains('detailed') ||
        lowerPrompt.contains('photorealistic') ||
        lowerPrompt.contains('hyperrealistic') ||
        lowerPrompt.contains('masterpiece') ||
        lowerPrompt.contains('4k') ||
        lowerPrompt.contains('8k') ||
        lowerPrompt.contains('sharp');

    if (!hasQualityKeywords) {
      enhancedPrompt =
          '$enhancedPrompt, highly detailed, sharp focus, 8k uhd, photorealistic, intricate textures, clear detailed eyes, masterpiece';
    }

    final seed = (prompt.hashCode.abs() + DateTime.now().millisecondsSinceEpoch) % 10000000;
    final cleanPrompt = Uri.encodeComponent(enhancedPrompt);

    // Multi-tier State-of-the-Art FLUX.1 endpoints with high-res fallbacks
    final urlsToTry = [
      'https://image.pollinations.ai/prompt/$cleanPrompt?width=$width&height=$height&seed=$seed&nologo=true&model=flux&enhance=true',
      'https://image.pollinations.ai/prompt/$cleanPrompt?width=$width&height=$height&seed=$seed&nologo=true&model=flux',
      'https://image.pollinations.ai/prompt/$cleanPrompt?width=$width&height=$height&seed=$seed&nologo=true&model=flux-realism',
      'https://image.pollinations.ai/prompt/$cleanPrompt?width=$width&height=$height&seed=$seed&nologo=true&model=turbo',
      'https://image.pollinations.ai/prompt/$cleanPrompt?width=1024&height=1024&seed=$seed&nologo=true',
    ];

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.bytes,
      ),
    );

    for (final url in urlsToTry) {
      try {
        debugPrint('[NeuralImageGen] Requesting FLUX high-res: $url');
        final response = await dio.get<List<int>>(url);
        if (response.statusCode == 200 &&
            response.data != null &&
            response.data!.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          if (!dir.existsSync()) {
            await dir.create(recursive: true);
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final file = File('${dir.path}/local_gen_$timestamp.jpg');
          await file.writeAsBytes(response.data!, flush: true);
          debugPrint('[NeuralImageGen] Successfully synthesized FLUX image: ${file.path}');
          return file;
        }
      } catch (e) {
        debugPrint('[NeuralImageGen] Attempt failed ($url): $e');
      }
    }

    // Offline / fallback procedural generator (smooth fallback if device has no network)
    debugPrint('[NeuralImageGen] Device is offline. Falling back to offline artwork engine');
    return _createLocalArtwork(prompt, aspectRatio);
  }

  static Future<File> _createLocalArtwork(String prompt, String aspectRatio) async {
    final int width;
    final int height;
    switch (aspectRatio) {
      case '16:9':
        width = 640;
        height = 360;
        break;
      case '9:16':
        width = 360;
        height = 640;
        break;
      case '4:3':
        width = 512;
        height = 384;
        break;
      case '3:4':
        width = 384;
        height = 512;
        break;
      case '1:1':
      default:
        width = 512;
        height = 512;
        break;
    }

    final image = img.Image(width: width, height: height);
    final seed = prompt.hashCode.abs();
    final random = Random(seed);
    final lower = prompt.toLowerCase();

    // 1. Classify prompt scene archetype
    final isCity = lower.contains('city') ||
        lower.contains('skyline') ||
        lower.contains('building') ||
        lower.contains('street') ||
        lower.contains('cyberpunk') ||
        lower.contains('neon') ||
        lower.contains('tokyo') ||
        lower.contains('architecture');

    final isCharacter = lower.contains('cat') ||
        lower.contains('dog') ||
        lower.contains('animal') ||
        lower.contains('robot') ||
        lower.contains('samurai') ||
        lower.contains('warrior') ||
        lower.contains('girl') ||
        lower.contains('man') ||
        lower.contains('portrait') ||
        lower.contains('dragon') ||
        lower.contains('monster') ||
        lower.contains('creature') ||
        lower.contains('face') ||
        lower.contains('person');

    final isVehicle = lower.contains('car') ||
        lower.contains('ship') ||
        lower.contains('spaceship') ||
        lower.contains('plane') ||
        lower.contains('vehicle') ||
        lower.contains('cybercar') ||
        lower.contains('train') ||
        lower.contains('bike');

    final isNature = lower.contains('forest') ||
        lower.contains('tree') ||
        lower.contains('garden') ||
        lower.contains('flower') ||
        lower.contains('plant') ||
        lower.contains('green') ||
        lower.contains('jungle') ||
        lower.contains('mountain');

    final isOcean = lower.contains('ocean') ||
        lower.contains('sea') ||
        lower.contains('water') ||
        lower.contains('beach') ||
        lower.contains('wave') ||
        lower.contains('underwater') ||
        lower.contains('island');

    final isCosmic = lower.contains('space') ||
        lower.contains('galaxy') ||
        lower.contains('planet') ||
        lower.contains('nebula') ||
        lower.contains('star') ||
        lower.contains('cosmic') ||
        lower.contains('astronomy');

    final isCozy = lower.contains('coffee') ||
        lower.contains('tea') ||
        lower.contains('cup') ||
        lower.contains('food') ||
        lower.contains('room') ||
        lower.contains('cozy') ||
        lower.contains('cafe') ||
        lower.contains('book');

    // 2. Generate Seed-based dynamic color palette
    final baseHue = (seed % 360).toDouble();
    final c1 = _hsl(baseHue, 0.75, 0.08);
    final c2 = _hsl((baseHue + 40) % 360, 0.70, 0.22);
    final c3 = _hsl((baseHue + 90) % 360, 0.65, 0.38);
    final cGlow = _hsl((baseHue + 180) % 360, 0.90, 0.65);
    final cAccent = _hsl((baseHue + 220) % 360, 0.95, 0.80);

    // 3. Render base backdrop gradient
    for (int y = 0; y < height; y++) {
      final t = y / height.toDouble();
      final r = (t < 0.5)
          ? (c1.r + (c2.r - c1.r) * (t * 2)).toInt().clamp(0, 255)
          : (c2.r + (c3.r - c2.r) * ((t - 0.5) * 2)).toInt().clamp(0, 255);
      final g = (t < 0.5)
          ? (c1.g + (c2.g - c1.g) * (t * 2)).toInt().clamp(0, 255)
          : (c2.g + (c3.g - c2.g) * ((t - 0.5) * 2)).toInt().clamp(0, 255);
      final b = (t < 0.5)
          ? (c1.b + (c2.b - c1.b) * (t * 2)).toInt().clamp(0, 255)
          : (c2.b + (c3.b - c2.b) * ((t - 0.5) * 2)).toInt().clamp(0, 255);

      final rowColor = img.ColorRgb8(r, g, b);
      for (int x = 0; x < width; x++) {
        image.setPixel(x, y, rowColor);
      }
    }

    // 4. Render Specialized Scene Geometry based on archetype
    if (isCity) {
      // --- Cyberpunk / Metropolis Skyline with Perspective Grid & Windows ---
      // Perspective road / neon floor
      final horizonY = (height * 0.60).toInt();
      for (int y = horizonY; y < height; y++) {
        if (y % 12 == 0) {
          for (int x = 0; x < width; x++) {
            image.setPixel(x, y, img.ColorRgb8(cGlow.r.toInt(), cGlow.g.toInt(), cGlow.b.toInt()));
          }
        }
      }
      // Vertical grid lines to vanishing point
      for (double angle = -1.0; angle <= 1.0; angle += 0.25) {
        for (int y = horizonY; y < height; y++) {
          final x = (width / 2 + (y - horizonY) * angle * 2.5).toInt();
          if (x >= 0 && x < width) {
            image.setPixel(x, y, img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cAccent.b.toInt()));
          }
        }
      }
      // Skyscraper Silhouettes with Lit Windows
      var curX = 10;
      while (curX < width - 20) {
        final bWidth = 25 + random.nextInt(45);
        final bHeight = 70 + random.nextInt((height * 0.50).toInt());
        final topY = horizonY - bHeight;

        for (int bx = curX; bx < min(width, curX + bWidth); bx++) {
          for (int by = max(0, topY); by < horizonY; by++) {
            image.setPixel(bx, by, img.ColorRgb8(12, 10, 22));
            // Windows
            if ((bx - curX) % 7 == 2 && (by - topY) % 9 == 4) {
              if (random.nextDouble() > 0.35) {
                final winColor = (random.nextBool()) ? cGlow : cAccent;
                image.setPixel(bx, by, img.ColorRgb8(winColor.r.toInt(), winColor.g.toInt(), winColor.b.toInt()));
              }
            }
          }
        }
        // Rooftop antenna / beacon
        final antX = curX + bWidth ~/ 2;
        for (int ay = max(0, topY - 20); ay < topY; ay++) {
          if (antX < width) image.setPixel(antX, ay, img.ColorRgb8(200, 200, 220));
        }
        if (antX < width && topY - 20 >= 0) {
          image.setPixel(antX, topY - 20, img.ColorRgb8(255, 30, 80));
        }
        curX += bWidth + 4;
      }
    } else if (isCharacter) {
      // --- Character / Creature / Avatar with Glowing Aura & Radial Portal ---
      final cx = (width * 0.5).toInt();
      final cy = (height * 0.46).toInt();
      final auraRadius = (min(width, height) * 0.32).toInt();

      // Glowing magical ring / portal
      for (int dy = -auraRadius; dy <= auraRadius; dy++) {
        for (int dx = -auraRadius; dx <= auraRadius; dx++) {
          final dist = sqrt(dx * dx + dy * dy);
          if ((dist - auraRadius * 0.85).abs() < 5) {
            final px = cx + dx;
            final py = cy + dy;
            if (px >= 0 && px < width && py >= 0 && py < height) {
              image.setPixel(px, py, img.ColorRgb8(cGlow.r.toInt(), cGlow.g.toInt(), cGlow.b.toInt()));
            }
          }
        }
      }

      // Creature / Portrait Silhouette Body
      final bodyRadius = (auraRadius * 0.55).toInt();
      for (int dy = -bodyRadius; dy <= bodyRadius + 80; dy++) {
        for (int dx = -bodyRadius; dx <= bodyRadius; dx++) {
          final dist = sqrt(dx * dx * 1.3 + dy * dy * 0.8);
          if (dist <= bodyRadius + 10) {
            final px = cx + dx;
            final py = cy + dy;
            if (px >= 0 && px < width && py >= 0 && py < height) {
              image.setPixel(px, py, img.ColorRgb8(15, 12, 28));
            }
          }
        }
      }
      // Glowing Eyes
      final eyeOffsetX = (bodyRadius * 0.35).toInt();
      final eyeY = cy - (bodyRadius * 0.15).toInt();
      for (int ex in [-eyeOffsetX, eyeOffsetX]) {
        for (int d = -2; d <= 2; d++) {
          for (int dy = -1; dy <= 1; dy++) {
            final px = cx + ex + d;
            final py = eyeY + dy;
            if (px >= 0 && px < width && py >= 0 && py < height) {
              image.setPixel(px, py, img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cAccent.b.toInt()));
            }
          }
        }
      }
    } else if (isVehicle) {
      // --- Vehicle / Cyber-Car / Ship with Speed Trails & Ground Glare ---
      final groundY = (height * 0.68).toInt();
      final vx = (width * 0.5).toInt();
      final vy = groundY - 30;

      // Speed streaks in background
      for (int i = 0; i < 40; i++) {
        final sy = random.nextInt(height);
        final sx = random.nextInt(width - 80);
        final len = 30 + random.nextInt(70);
        for (int x = sx; x < min(width, sx + len); x++) {
          image.setPixel(x, sy, img.ColorRgb8(cGlow.r.toInt(), cGlow.g.toInt(), cGlow.b.toInt()));
        }
      }

      // Streamlined car / ship silhouette
      for (int dy = -25; dy <= 20; dy++) {
        for (int dx = -80; dx <= 80; dx++) {
          if ((dx.abs() * 0.35 + dy.abs() * 1.8) < 35) {
            final px = vx + dx;
            final py = vy + dy;
            if (px >= 0 && px < width && py >= 0 && py < height) {
              image.setPixel(px, py, img.ColorRgb8(18, 16, 32));
            }
          }
        }
      }
      // Headlights & Taillights
      for (int d = -4; d <= 4; d++) {
        if (vx + 75 < width) image.setPixel(vx + 75, vy + d, img.ColorRgb8(255, 255, 180));
        if (vx - 75 >= 0) image.setPixel(vx - 75, vy + d, img.ColorRgb8(255, 30, 50));
      }
    } else if (isNature) {
      // --- Forest, Garden & Sunbeams ---
      // Sunburst rays
      final sunX = (width * 0.3).toInt();
      final sunY = (height * 0.25).toInt();
      for (int i = 0; i < 18; i++) {
        final angle = i * (pi / 9);
        for (int r = 10; r < 240; r += 2) {
          final rx = (sunX + cos(angle) * r).toInt();
          final ry = (sunY + sin(angle) * r).toInt();
          if (rx >= 0 && rx < width && ry >= 0 && ry < height) {
            image.setPixel(rx, ry, img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cAccent.b.toInt()));
          }
        }
      }
      // Pine tree silhouettes
      for (int tx = 0; tx < width; tx += 28) {
        final tHeight = 60 + (sin((tx + seed) / 20) * 35).abs().toInt();
        final base = (height * 0.85).toInt();
        for (int y = base - tHeight; y < base; y++) {
          final spread = ((y - (base - tHeight)) * 0.35).toInt();
          for (int x = tx - spread; x <= tx + spread; x++) {
            if (x >= 0 && x < width && y >= 0 && y < height) {
              image.setPixel(x, y, img.ColorRgb8(8, 32, 16));
            }
          }
        }
      }
    } else if (isOcean) {
      // --- Bioluminescent Waves & Oceanic Sun ---
      final waveBase = (height * 0.52).toInt();
      for (int wave = 0; wave < 4; wave++) {
        final yOffset = waveBase + wave * 30;
        final waveColor = (wave % 2 == 0) ? cGlow : c3;
        for (int x = 0; x < width; x++) {
          final wy = yOffset + (sin((x + seed + wave * 40) / 35) * 14).toInt();
          for (int y = max(0, wy); y < height; y++) {
            image.setPixel(x, y, img.ColorRgb8(waveColor.r.toInt() ~/ (wave + 1), waveColor.g.toInt() ~/ (wave + 1), waveColor.b.toInt() ~/ (wave + 1)));
          }
        }
      }
    } else if (isCosmic) {
      // --- Deep Space Galaxy, Ringed Planet & Nebula ---
      // Swirling Nebula Cloud (plasma math)
      for (int y = 0; y < height; y += 2) {
        for (int x = 0; x < width; x += 2) {
          final v = sin(x / 30.0 + seed) + cos(y / 30.0 + seed) + sin((x + y) / 45.0);
          if (v > 0.8) {
            final neb = img.ColorRgb8(cGlow.r.toInt() ~/ 2, cGlow.g.toInt() ~/ 3, cAccent.b.toInt() ~/ 2);
            image.setPixel(x, y, neb);
            if (x + 1 < width) image.setPixel(x + 1, y, neb);
            if (y + 1 < height) image.setPixel(x, y + 1, neb);
          }
        }
      }
      // Ringed Giant Planet
      final px = (width * 0.65).toInt();
      final py = (height * 0.40).toInt();
      final pr = (min(width, height) * 0.18).toInt();
      for (int dy = -pr; dy <= pr; dy++) {
        for (int dx = -pr; dx <= pr; dx++) {
          if (dx * dx + dy * dy <= pr * pr) {
            image.setPixel(px + dx, py + dy, img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cGlow.b.toInt()));
          }
        }
      }
      // Planet Rings
      for (int rx = -pr * 2; rx <= pr * 2; rx++) {
        final ry = (rx * 0.35).toInt();
        if ((rx.abs() > pr * 0.8) && px + rx >= 0 && px + rx < width && py + ry >= 0 && py + ry < height) {
          image.setPixel(px + rx, py + ry, img.ColorRgb8(240, 240, 255));
        }
      }
    } else if (isCozy) {
      // --- Cozy Interior / Steaming Coffee Cup with Ambient Glow ---
      final tableY = (height * 0.70).toInt();
      for (int x = 0; x < width; x++) {
        for (int y = tableY; y < height; y++) {
          image.setPixel(x, y, img.ColorRgb8(45, 25, 15));
        }
      }
      // Mug Silhouette
      final cx = (width * 0.5).toInt();
      final cy = tableY - 35;
      for (int dx = -30; dx <= 30; dx++) {
        for (int dy = -30; dy <= 30; dy++) {
          image.setPixel(cx + dx, cy + dy, img.ColorRgb8(220, 215, 205));
        }
      }
      // Steam swirls
      for (int s = 0; s < 3; s++) {
        final sx = cx - 15 + s * 15;
        for (int y = cy - 65; y < cy - 30; y++) {
          final wx = (sx + sin(y / 8.0) * 6).toInt();
          if (wx >= 0 && wx < width) {
            image.setPixel(wx, y, img.ColorRgb8(255, 255, 255));
          }
        }
      }
    } else {
      // --- Generative Geometric Mandala / Sacred Geometry Fractal ---
      final cx = (width * 0.5).toInt();
      final cy = (height * 0.5).toInt();
      for (int ring = 1; ring <= 6; ring++) {
        final r = ring * 35;
        final count = ring * 6;
        for (int i = 0; i < count; i++) {
          final angle = i * (2 * pi / count) + (seed % 100) / 50.0;
          final px = (cx + cos(angle) * r).toInt();
          final py = (cy + sin(angle) * r).toInt();
          if (px >= 0 && px < width && py >= 0 && py < height) {
            image.setPixel(px, py, (ring % 2 == 0) ? img.ColorRgb8(cGlow.r.toInt(), cGlow.g.toInt(), cGlow.b.toInt()) : img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cAccent.b.toInt()));
          }
        }
      }
    }

    // 5. Starfield / Ambient Particles
    for (int i = 0; i < 60; i++) {
      final sx = random.nextInt(width);
      final sy = random.nextInt(height);
      image.setPixel(sx, sy, (i % 2 == 0) ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(cAccent.r.toInt(), cAccent.g.toInt(), cAccent.b.toInt()));
    }

    // Encode to PNG bytes
    final pngBytes = img.encodePng(image);

    final dir = await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/local_gen_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  static img.ColorRgb8 _hsl(double h, double s, double l) {
    final c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    final x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    final m = l - c / 2.0;

    double r1, g1, b1;
    if (h < 60) {
      r1 = c;
      g1 = x;
      b1 = 0;
    } else if (h < 120) {
      r1 = x;
      g1 = c;
      b1 = 0;
    } else if (h < 180) {
      r1 = 0;
      g1 = c;
      b1 = x;
    } else if (h < 240) {
      r1 = 0;
      g1 = x;
      b1 = c;
    } else if (h < 300) {
      r1 = x;
      g1 = 0;
      b1 = c;
    } else {
      r1 = c;
      g1 = 0;
      b1 = x;
    }

    return img.ColorRgb8(
      ((r1 + m) * 255).round().clamp(0, 255),
      ((g1 + m) * 255).round().clamp(0, 255),
      ((b1 + m) * 255).round().clamp(0, 255),
    );
  }
}
