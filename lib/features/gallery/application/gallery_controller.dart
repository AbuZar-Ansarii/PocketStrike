import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketstrike/features/gallery/data/gallery_item.dart';

const _galleryChannel = MethodChannel('com.pocketstrike.app/gallery');

final galleryControllerProvider =
    StateNotifierProvider<GalleryController, AsyncValue<List<GalleryItem>>>((ref) {
  return GalleryController()..loadImages();
});

final galleryImagesProvider = Provider<AsyncValue<List<GalleryItem>>>((ref) {
  return ref.watch(galleryControllerProvider);
});

class GalleryController extends StateNotifier<AsyncValue<List<GalleryItem>>> {
  GalleryController() : super(const AsyncValue.loading());

  Future<void> loadImages() async {
    try {
      final items = <GalleryItem>[];
      final seenPaths = <String>{};

      // 1. App Documents Directory (where local_gen_*.jpg files are created by the AI engine)
      try {
        final docDir = await getApplicationDocumentsDirectory();
        if (docDir.existsSync()) {
          final files = docDir.listSync(followLinks: false);
          for (final f in files) {
            if (f is File) {
              final lower = f.path.toLowerCase();
              if (lower.endsWith('.jpg') ||
                  lower.endsWith('.jpeg') ||
                  lower.endsWith('.png') ||
                  lower.endsWith('.webp')) {
                if (!seenPaths.contains(f.path)) {
                  seenPaths.add(f.path);
                  final stat = f.statSync();
                  final fileName = f.uri.pathSegments.last;
                  final isSavedToPhone = File(
                          '/storage/emulated/0/Pictures/PocketStrike/$fileName')
                      .existsSync();
                  items.add(GalleryItem(
                    filePath: f.path,
                    fileName: fileName,
                    fileSizeBytes: stat.size,
                    createdAt: stat.modified,
                    isSavedInPhoneGallery: isSavedToPhone,
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[GalleryController] Error reading app documents: $e');
      }

      // Sort newest first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Saves the image file into Android MediaStore (Pictures/PocketStrike)
  Future<bool> saveToPhoneGallery(GalleryItem item) async {
    try {
      final file = File(item.filePath);
      if (!file.existsSync()) return false;

      final bytes = await file.readAsBytes();
      final result = await _galleryChannel.invokeMethod<String>(
        'saveImageToGallery',
        {
          'bytes': bytes,
          'fileName': item.fileName.startsWith('PocketStrike_')
              ? item.fileName
              : 'PocketStrike_${DateTime.now().millisecondsSinceEpoch}.jpg',
        },
      );

      if (result != null) {
        await loadImages();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GalleryController] saveToPhoneGallery error: $e');
      return false;
    }
  }

  /// Shares the image via system share sheet
  Future<bool> shareImage(GalleryItem item, {String? caption}) async {
    try {
      final result = await _galleryChannel.invokeMethod<bool>(
        'shareImage',
        {
          'filePath': item.filePath,
          'text': caption ?? 'Created with PocketStrike AI',
        },
      );
      return result ?? false;
    } catch (e) {
      debugPrint('[GalleryController] shareImage error: $e');
      return false;
    }
  }

  /// Deletes the image from the app's internal storage and clears RAM cache,
  /// keeping any copy the user saved to their phone gallery safe on storage.
  Future<bool> deleteImage(GalleryItem item) async {
    try {
      // 1. Evict from Flutter in-memory decoded image cache
      try {
        final file = File(item.filePath);
        FileImage(file).evict();
      } catch (_) {}

      // 2. Physical file deletion on internal app storage
      final file = File(item.filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      await loadImages();
      return true;
    } catch (e) {
      debugPrint('[GalleryController] deleteImage error: $e');
      return false;
    }
  }

  /// Batch deletes multiple images from app storage, preserving phone gallery storage
  Future<void> deleteMultiple(List<GalleryItem> items) async {
    for (final item in items) {
      try {
        final file = File(item.filePath);
        FileImage(file).evict();
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    await loadImages();
  }
}
