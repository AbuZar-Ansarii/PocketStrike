import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/features/gallery/application/gallery_controller.dart';
import 'package:pocketstrike/features/gallery/data/gallery_item.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';

class ImagePreviewDialog extends ConsumerStatefulWidget {
  const ImagePreviewDialog({
    super.key,
    required this.item,
  });

  final GalleryItem item;

  static Future<void> show(BuildContext context, GalleryItem item) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      pageBuilder: (context, anim1, anim2) => ImagePreviewDialog(item: item),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends ConsumerState<ImagePreviewDialog> {
  bool _isSaving = false;
  bool _isSharing = false;

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    final success = await ref
        .read(galleryControllerProvider.notifier)
        .saveToPhoneGallery(widget.item);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2430),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? const Color(0xFF00FFCC) : Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Saved to Gallery in Pictures/PocketStrike'
                    : 'Failed to save image to gallery',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShare() async {
    setState(() => _isSharing = true);
    HapticFeedback.lightImpact();
    await ref.read(galleryControllerProvider.notifier).shareImage(widget.item);
    if (mounted) {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _handleDelete() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        title: Row(
          children: [
            const Icon(AppIcons.trash, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Text(
              'Delete from App?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Delete this image from the app gallery? Any copy you saved to your phone\'s Gallery will remain safe on your device storage.',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.heavyImpact();
      await ref
          .read(galleryControllerProvider.notifier)
          .deleteImage(widget.item);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E2430),
            content: Text('Image deleted successfully'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final file = File(widget.item.filePath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Zoomable Image
            Positioned.fill(
              child: exists
                  ? Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.5,
                        clipBehavior: Clip.none,
                        child: Hero(
                          tag: 'gallery_${widget.item.filePath}',
                          child: Image.file(
                            file,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Image file no longer available on storage.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
            ),

            // Top Header Action Bar
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${widget.item.formattedDate} · ${widget.item.formattedSize}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Pill Bar
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141822).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: tokens.glassBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Save to Gallery
                      _ActionButton(
                        icon: Icons.download_rounded,
                        label: 'Save',
                        color: tokens.accent,
                        isLoading: _isSaving,
                        onTap: _handleSave,
                      ),
                      const SizedBox(width: 14),

                      // Share
                      _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        color: const Color(0xFF38BDF8),
                        isLoading: _isSharing,
                        onTap: _handleShare,
                      ),
                      const SizedBox(width: 14),

                      // Delete
                      _ActionButton(
                        icon: AppIcons.trash,
                        label: 'Delete',
                        color: Colors.redAccent,
                        onTap: _handleDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
