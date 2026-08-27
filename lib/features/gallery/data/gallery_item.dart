import 'package:intl/intl.dart';

class GalleryItem {
  const GalleryItem({
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.createdAt,
    this.isSavedInPhoneGallery = false,
  });

  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final DateTime createdAt;
  final bool isSavedInPhoneGallery;

  String get formattedSize {
    if (fileSizeBytes >= 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  String get formattedDate {
    return DateFormat('MMM d, h:mm a').format(createdAt);
  }

  String get formattedDateLong {
    return DateFormat('EEEE, MMMM d, yyyy · h:mm a').format(createdAt);
  }
}
