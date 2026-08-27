import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/features/gallery/application/gallery_controller.dart';
import 'package:pocketstrike/features/gallery/data/gallery_item.dart';
import 'package:pocketstrike/features/gallery/ui/image_preview_dialog.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/empty_state.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  int _crossAxisCount = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.glass;
    final imagesAsync = ref.watch(galleryImagesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(AppIcons.image, size: 20, color: tokens.accent),
            const SizedBox(width: 8),
            Text(
              'AI Image Gallery',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          // Grid Columns Toggle (2 or 3)
          IconButton(
            tooltip: _crossAxisCount == 2 ? '3 Columns' : '2 Columns',
            icon: Icon(
              _crossAxisCount == 2
                  ? Icons.grid_view_rounded
                  : Icons.view_compact_rounded,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _crossAxisCount = _crossAxisCount == 2 ? 3 : 2;
              });
            },
          ),

          // Refresh button
          IconButton(
            tooltip: 'Refresh Gallery',
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(galleryControllerProvider.notifier).loadImages();
            },
          ),
        ],
      ),
      body: imagesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: tokens.accent),
        ),
        error: (err, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load gallery',
            message: err.toString(),
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(galleryControllerProvider.notifier).loadImages(),
          ),
        ),
        data: (images) {
          if (images.isEmpty) {
            return EmptyState(
              icon: AppIcons.image,
              title: 'No AI Images Yet',
              message:
                  'Images generated in chat with /image or the FLUX Diffusion engine will appear here automatically.',
              actionLabel: '🎨 Create New Image',
              onAction: () {
                context.go(AppRoutes.chat);
              },
            );
          }

          return RefreshIndicator(
            color: tokens.accent,
            backgroundColor: theme.colorScheme.surface,
            onRefresh: () =>
                ref.read(galleryControllerProvider.notifier).loadImages(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final item = images[index];
                return _GalleryGridCard(
                  item: item,
                  isDark: isDark,
                  onTap: () => ImagePreviewDialog.show(context, item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GalleryGridCard extends ConsumerWidget {
  const _GalleryGridCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final GalleryItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final file = File(item.filePath);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? tokens.terminalSurface : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? tokens.glassBorder
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: 0.8,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Thumbnail
              if (file.existsSync())
                Hero(
                  tag: 'gallery_${item.filePath}',
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                )
              else
                Container(
                  color: isDark ? Colors.black45 : Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ),
                ),

              // Bottom Gradient & Metadata Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          item.formattedDate,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.formattedSize,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
