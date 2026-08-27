import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/code_block.dart';

/// Renders assistant/user text as markdown with glass code blocks and local image rendering.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);

    final parts = _parseMarkdownParts(text);

    if (parts.length == 1 && parts.first is _TextMarkdownPart) {
      return _buildMarkdownBody(
        context,
        (parts.first as _TextMarkdownPart).text,
        tokens,
        theme,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in parts)
          if (part is _TextMarkdownPart)
            _buildMarkdownBody(context, part.text, tokens, theme)
          else if (part is _TableMarkdownPart)
            _ModernMarkdownTable(
              headers: part.headers,
              rows: part.rows,
            ),
      ],
    );
  }

  static Widget _buildMarkdownBody(
    BuildContext context,
    String markdownData,
    GlassTokens tokens,
    ThemeData theme,
  ) {
    return MarkdownBody(
      data: markdownData,
      selectable: false,
      sizedImageBuilder: (config) {
        return _InteractiveImageCard(
          uri: config.uri,
          alt: config.alt ?? config.title,
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
          height: 1.45,
          fontSize: 13.5,
          letterSpacing: 0.1,
        ),
        h1: theme.textTheme.titleLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h2: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        h3: theme.textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        code: AppTheme.mono(
          fontSize: 12,
          color: tokens.accent,
        ),
        codeblockDecoration: const BoxDecoration(),
        blockquoteDecoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border(
            left: BorderSide(color: tokens.accent, width: 3),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        listBullet: theme.textTheme.bodyMedium?.copyWith(
          color: tokens.accent,
          fontWeight: FontWeight.bold,
        ),
      ),
      builders: {
        'code': _CodeElementBuilder(),
      },
    );
  }
}

sealed class _MarkdownPart {}

class _TextMarkdownPart extends _MarkdownPart {
  final String text;
  _TextMarkdownPart(this.text);
}

class _TableMarkdownPart extends _MarkdownPart {
  final List<String> headers;
  final List<List<String>> rows;
  _TableMarkdownPart({required this.headers, required this.rows});
}

List<_MarkdownPart> _parseMarkdownParts(String text) {
  final parts = <_MarkdownPart>[];
  final lines = text.split('\n');
  final delimiterRegex =
      RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$');

  List<String> parseTableRow(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((c) => c.trim()).toList();
  }

  final buffer = StringBuffer();
  int i = 0;
  bool inCodeBlock = false;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      buffer.writeln(line);
      i++;
      continue;
    }

    if (!inCodeBlock && i + 1 < lines.length) {
      final nextTrimmed = lines[i + 1].trim();
      if (trimmed.contains('|') && delimiterRegex.hasMatch(nextTrimmed)) {
        // Table detected starting at index i
        if (buffer.isNotEmpty) {
          final prefixText = buffer.toString().trimRight();
          if (prefixText.isNotEmpty) {
            parts.add(_TextMarkdownPart(prefixText));
          }
          buffer.clear();
        }

        final headers = parseTableRow(trimmed);
        i += 2; // Skip header and delimiter

        final rows = <List<String>>[];
        while (i < lines.length) {
          final rowTrimmed = lines[i].trim();
          if (rowTrimmed.isEmpty || !rowTrimmed.contains('|')) {
            break;
          }
          rows.add(parseTableRow(rowTrimmed));
          i++;
        }

        parts.add(_TableMarkdownPart(headers: headers, rows: rows));
        continue;
      }
    }

    buffer.writeln(line);
    i++;
  }

  if (buffer.isNotEmpty) {
    final remaining = buffer.toString().trimRight();
    if (remaining.isNotEmpty) {
      parts.add(_TextMarkdownPart(remaining));
    }
  }

  return parts.isEmpty ? [_TextMarkdownPart(text)] : parts;
}

/// Interactive Glass Image Card for local and remote generated artwork.
class _InteractiveImageCard extends StatelessWidget {
  const _InteractiveImageCard({required this.uri, this.alt});

  final Uri uri;
  final String? alt;

  double _getAspectRatio(String? caption) {
    if (caption != null) {
      if (caption.contains('16:9')) return 16 / 9;
      if (caption.contains('9:16')) return 9 / 16;
      if (caption.contains('4:3')) return 4 / 3;
      if (caption.contains('3:4')) return 3 / 4;
    }
    return 1.0; // Default 1:1 square
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final uriStr = uri.toString();
    File? localFile;

    if (uri.scheme == 'file' || uriStr.startsWith('file:') || uriStr.startsWith('/')) {
      String cleanPath = uriStr;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
        if (!cleanPath.startsWith('/')) {
          cleanPath = '/$cleanPath';
        }
      } else if (cleanPath.startsWith('file:')) {
        cleanPath = cleanPath.substring(5);
        if (!cleanPath.startsWith('/')) {
          cleanPath = '/$cleanPath';
        }
      }
      localFile = File(cleanPath);
    }

    final isRemote = uri.scheme == 'http' || uri.scheme == 'https';
    final ratio = _getAspectRatio(alt);

    Widget imageWidget;
    if (localFile != null && localFile.existsSync()) {
      imageWidget = AspectRatio(
        aspectRatio: ratio,
        child: Image.file(
          localFile,
          fit: BoxFit.cover,
          width: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Container(
              color: tokens.glassBorder.withValues(alpha: 0.15),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _errorPlaceholder(tokens, 'Error rendering generated image'),
        ),
      );
    } else if (isRemote) {
      imageWidget = AspectRatio(
        aspectRatio: ratio,
        child: Image.network(
          uriStr,
          fit: BoxFit.cover,
          width: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Container(
              color: tokens.glassBorder.withValues(alpha: 0.15),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _errorPlaceholder(tokens, 'Error loading network image'),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.glassColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tokens.accent.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openFullScreenViewer(context, localFile, uriStr);
                },
                child: imageWidget,
              ),

              // Top Actions: Zoom & Quick Download
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _downloadImage(context, localFile, uriStr),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.6,
                            ),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Fullscreen Zoom Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openFullScreenViewer(context, localFile, uriStr);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.6,
                            ),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 16,
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
      ),
    );
  }

  Widget _errorPlaceholder(GlassTokens tokens, String message) {
    return Container(
      height: 140,
      width: double.infinity,
      color: tokens.glassBorder.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.image, size: 16, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadImage(
    BuildContext context,
    File? localFile,
    String uriStr,
  ) async {
    try {
      HapticFeedback.mediumImpact();
      Uint8List bytes;
      if (localFile != null && localFile.existsSync()) {
        bytes = await localFile.readAsBytes();
      } else {
        final dio = Dio();
        final response = await dio.get<List<int>>(
          uriStr,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data == null) throw Exception('No image data received');
        bytes = Uint8List.fromList(response.data!);
      }

      final fileName = 'PocketStrike_${DateTime.now().millisecondsSinceEpoch}.jpg';
      bool savedNative = false;

      // 1. Android Native MediaStore save (instantly visible in Gallery / Google Photos)
      if (Platform.isAndroid) {
        try {
          const channel = MethodChannel('com.pocketstrike.app/gallery');
          final res = await channel.invokeMethod<String>('saveImageToGallery', {
            'bytes': bytes,
            'fileName': fileName,
          });
          if (res != null && res.isNotEmpty) {
            savedNative = true;
          }
        } catch (err) {
          debugPrint('[GallerySaver] MethodChannel save failed: $err');
        }
      }

      // 2. Physical File backup in standard media directories
      final candidateDirs = [
        Directory('/storage/emulated/0/Pictures/PocketStrike'),
        Directory('/storage/emulated/0/DCIM/PocketStrike'),
        Directory('/storage/emulated/0/Download'),
      ];

      File? savedFile;
      for (final dir in candidateDirs) {
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          if (dir.existsSync()) {
            final target = File('${dir.path}/$fileName');
            await target.writeAsBytes(bytes, flush: true);
            savedFile = target;

            // Trigger system MediaScanner on physical file
            if (Platform.isAndroid) {
              try {
                const channel = MethodChannel('com.pocketstrike.app/gallery');
                await channel.invokeMethod('scanFilePath', {'filePath': target.absolute.path});
              } catch (_) {}
            }
            break;
          }
        } catch (_) {}
      }

      if (savedFile == null && !savedNative) {
        final appDir = await getApplicationDocumentsDirectory();
        final target = File('${appDir.path}/$fileName');
        await target.writeAsBytes(bytes, flush: true);
        savedFile = target;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved to Phone Gallery',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Album: Pictures / PocketStrike',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static Future<void> _shareImage(BuildContext context, File? file, String uriStr) async {
    try {
      HapticFeedback.lightImpact();
      if (file != null && file.existsSync()) {
        const channel = MethodChannel('com.pocketstrike.app/gallery');
        await channel.invokeMethod('shareImage', {
          'filePath': file.absolute.path,
          'text': 'Created with PocketStrike AI',
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openFullScreenViewer(BuildContext context, File? file, String uriStr) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Fullscreen Frosted Glass Blur Backdrop
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogCtx).pop(),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Interactive Centered Image Viewer with pinch/zoom/pan
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 70),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: file != null && file.existsSync()
                          ? Image.file(file, fit: BoxFit.contain)
                          : Image.network(uriStr, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),

              // 3. Top Floating Glass Action Bar
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Share Button
                        if (file != null && file.existsSync())
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.share_rounded, color: Color(0xFF38BDF8), size: 18),
                              tooltip: 'Share Image',
                              onPressed: () => _shareImage(dialogCtx, file, uriStr),
                            ),
                          ),
                        if (file != null && file.existsSync())
                          const SizedBox(width: 8),

                        // Download Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                            tooltip: 'Save Image',
                            onPressed: () => _downloadImage(dialogCtx, file, uriStr),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Close Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Bottom Action Pills (Save & Share)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _downloadImage(dialogCtx, file, uriStr),
                          icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Save to Gallery',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        if (file != null && file.existsSync()) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _shareImage(dialogCtx, file, uriStr),
                            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }
}

/// Routes fenced code blocks to the glass [CodeBlock] widget.
class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language =
        (element.attributes['class'] ?? '').replaceFirst('language-', '');
    return CodeBlock(
      code: element.textContent.trimRight(),
      language: language.isEmpty ? null : language,
    );
  }
}

/// Executive Horizontally Scrollable Markdown Table Card (Hermes / OpenClaw style)
class _ModernMarkdownTable extends StatefulWidget {
  const _ModernMarkdownTable({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  @override
  State<_ModernMarkdownTable> createState() => _ModernMarkdownTableState();
}

class _ModernMarkdownTableState extends State<_ModernMarkdownTable> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 4;
    final canRight = currentScroll < maxScroll - 4;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final columnCount = widget.headers.isNotEmpty
        ? widget.headers.length
        : (widget.rows.isNotEmpty ? widget.rows.first.length : 0);

    if (columnCount == 0) return const SizedBox.shrink();

    final isScrollable = _canScrollLeft || _canScrollRight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.terminalSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isScrollable
                ? tokens.accent.withValues(alpha: 0.35)
                : tokens.glassBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top action bar with table label, scroll hint & buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.glassColor,
                border: Border(
                  bottom: BorderSide(
                    color: tokens.glassBorder.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Left: Table Icon & Row Count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_chart_rounded,
                        size: 13,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TABLE (${widget.rows.length} rows · $columnCount cols)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                          color: tokens.accent,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Horizontal Scroll indicator pill
                  if (isScrollable) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              size: 11, color: tokens.accent),
                          const SizedBox(width: 3),
                          Text(
                            'Swipe',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Expand Fullscreen Button
                  _TableActionBtn(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Expand Table',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showFullScreenTableDialog(
                        context,
                        widget.headers,
                        widget.rows,
                      );
                    },
                  ),
                  const SizedBox(width: 4),

                  // Copy Table Button
                  _TableActionBtn(
                    icon: AppIcons.copy,
                    tooltip: 'Copy Table',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final tableMd = _generateMarkdownTable(
                        widget.headers,
                        widget.rows,
                      );
                      Clipboard.setData(ClipboardData(text: tableMd));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Table markdown copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Table with Left/Right Fades
            Stack(
              children: [
                Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 4.0,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      children: [
                        // Header Row
                        if (widget.headers.isNotEmpty)
                          TableRow(
                            decoration: BoxDecoration(
                              color: tokens.accent.withValues(alpha: 0.14),
                              border: Border(
                                bottom: BorderSide(
                                  color: tokens.accent.withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                            ),
                            children: [
                              for (final header in widget.headers)
                                Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 105),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    header,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.accent,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                        // Data Rows
                        for (int r = 0; r < widget.rows.length; r++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: r % 2 == 1
                                  ? tokens.glassColor.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: tokens.glassBorder
                                      .withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            children: [
                              for (int c = 0; c < columnCount; c++)
                                Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 95),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    c < widget.rows[r].length
                                        ? widget.rows[r][c]
                                        : '',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // Left Edge Fade when scrolled
                if (_canScrollLeft)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              tokens.terminalSurface,
                              tokens.terminalSurface.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 14,
                          color: tokens.accent.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),

                // Right Edge Fade when more content available
                if (_canScrollRight)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              tokens.terminalSurface,
                              tokens.terminalSurface.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: tokens.accent.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _generateMarkdownTable(
      List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    if (headers.isNotEmpty) {
      buffer.writeln('| ${headers.join(' | ')} |');
      buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
    }
    for (final row in rows) {
      buffer.writeln('| ${row.join(' | ')} |');
    }
    return buffer.toString().trim();
  }

  static String _generateCsvTable(
      List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    if (headers.isNotEmpty) {
      buffer.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    }
    for (final row in rows) {
      buffer.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }
    return buffer.toString().trim();
  }
}

class _TableActionBtn extends StatelessWidget {
  const _TableActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(
          icon,
          size: 13,
          color: context.glass.textSecondary,
        ),
      ),
    );
  }
}

/// Full-screen Interactive Table Inspector Dialog with Search, 2D Scroll, and CSV Copy
void _showFullScreenTableDialog(
  BuildContext context,
  List<String> headers,
  List<List<String>> rows,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FullScreenTableSheet(headers: headers, rows: rows),
  );
}

class _FullScreenTableSheet extends StatefulWidget {
  const _FullScreenTableSheet({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  @override
  State<_FullScreenTableSheet> createState() => _FullScreenTableSheetState();
}

class _FullScreenTableSheetState extends State<_FullScreenTableSheet> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchQuery.toLowerCase().trim();
    final filteredRows = query.isEmpty
        ? widget.rows
        : widget.rows.where((row) {
            return row.any((cell) => cell.toLowerCase().contains(query));
          }).toList();

    final columnCount = widget.headers.isNotEmpty
        ? widget.headers.length
        : (widget.rows.isNotEmpty ? widget.rows.first.length : 0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: tokens.glassBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row with Title, CSV and Close
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(Icons.table_chart_rounded,
                    size: 16, color: tokens.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table Viewer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${filteredRows.length} rows · $columnCount columns',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final csv = _ModernMarkdownTableState._generateCsvTable(
                    widget.headers,
                    widget.rows,
                  );
                  Clipboard.setData(ClipboardData(text: csv));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Table copied as CSV (Excel format)'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(AppIcons.copy, size: 13),
                label: const Text('CSV', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field for Large Tables
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search within table…',
              hintStyle: TextStyle(fontSize: 13, color: tokens.textSecondary),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 16, color: tokens.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
              filled: true,
              fillColor: tokens.glassColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tokens.glassBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2D Scrollable Table Body
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: tokens.terminalSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.glassBorder, width: 0.8),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      // Header Row
                      if (widget.headers.isNotEmpty)
                        TableRow(
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.16),
                            border: Border(
                              bottom: BorderSide(
                                color: tokens.accent.withValues(alpha: 0.4),
                                width: 1.0,
                              ),
                            ),
                          ),
                          children: [
                            for (final header in widget.headers)
                              Container(
                                constraints:
                                    const BoxConstraints(minWidth: 100),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                child: Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),

                      // Filtered Rows
                      for (int r = 0; r < filteredRows.length; r++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: r % 2 == 1
                                ? tokens.glassColor.withValues(alpha: 0.25)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color:
                                    tokens.glassBorder.withValues(alpha: 0.35),
                                width: 0.5,
                              ),
                            ),
                          ),
                          children: [
                            for (int c = 0; c < columnCount; c++)
                               Container(
                                constraints:
                                    const BoxConstraints(minWidth: 100),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  c < filteredRows[r].length
                                      ? filteredRows[r][c]
                                      : '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


