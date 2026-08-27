import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/features/gallery/application/gallery_controller.dart';
import 'package:pocketstrike/features/gallery/data/gallery_item.dart';
import 'package:pocketstrike/features/gallery/ui/gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GalleryItem Model Tests', () {
    test('formats size correctly for KB and MB', () {
      final itemKb = GalleryItem(
        filePath: '/tmp/test1.jpg',
        fileName: 'test1.jpg',
        fileSizeBytes: 450 * 1024,
        createdAt: DateTime(2026, 8, 26, 17, 30),
      );
      expect(itemKb.formattedSize, '450 KB');

      final itemMb = GalleryItem(
        filePath: '/tmp/test2.jpg',
        fileName: 'test2.jpg',
        fileSizeBytes: (2.4 * 1024 * 1024).toInt(),
        createdAt: DateTime(2026, 8, 26, 17, 30),
      );
      expect(itemMb.formattedSize, '2.4 MB');
    });

    test('formats date correctly', () {
      final item = GalleryItem(
        filePath: '/tmp/test.jpg',
        fileName: 'test.jpg',
        fileSizeBytes: 1000,
        createdAt: DateTime(2026, 8, 26, 17, 30),
      );
      expect(item.formattedDate, contains('Aug 26'));
      expect(item.formattedDateLong, contains('2026'));
    });
  });

  group('GalleryScreen Widget Tests', () {
    testWidgets('renders empty state when no images are present', (tester) async {
      final container = ProviderContainer(
        overrides: [
          galleryControllerProvider.overrideWith((ref) {
            final c = GalleryController();
            c.state = const AsyncValue.data([]);
            return c;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const GalleryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Image Gallery'), findsOneWidget);
      expect(find.text('No AI Images Yet'), findsOneWidget);
      expect(find.text('🎨 Create New Image'), findsOneWidget);
    });

    testWidgets('renders grid cards when images are present', (tester) async {
      final sampleItem = GalleryItem(
        filePath: '/tmp/sample_image.jpg',
        fileName: 'sample_image.jpg',
        fileSizeBytes: 500 * 1024,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          galleryControllerProvider.overrideWith((ref) {
            final c = GalleryController();
            c.state = AsyncValue.data([sampleItem]);
            return c;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const GalleryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Image Gallery'), findsOneWidget);
      expect(find.text('500 KB'), findsOneWidget);
    });

    testWidgets('renders properly with light mode theme', (tester) async {
      final container = ProviderContainer(
        overrides: [
          galleryControllerProvider.overrideWith((ref) {
            final c = GalleryController();
            c.state = const AsyncValue.data([]);
            return c;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const GalleryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Image Gallery'), findsOneWidget);
      expect(find.text('No AI Images Yet'), findsOneWidget);
    });
  });
}
