import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/features/chat/ui/widgets/message_bubble.dart';

void main() {
  testWidgets('renders table inside MessageBubble with left-to-right horizontal scrolling', (tester) async {
    const content = '''
Here is the fork repository list you requested:

| Name | User name | Description | Status |
| :--- | :--- | :--- | :--- |
| the void kernel | ganme god | Custom high performance kernel modifications for mobile | Active |
| Mod d abus ar. | some user | Game modification and asset expansion pack | Stable |
| pocketstrike-executive-ai | orailnoor | Executive on-device AI workstation with GGUF & MCP | Updated |

Let me know if you need anything else!
''';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(
                message: Message(
                  id: 'msg-table-1',
                  conversationId: 'conv-1',
                  role: 'assistant',
                  content: content,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check that TABLE badge / header is found
    expect(find.textContaining('TABLE (3 rows · 4 cols)'), findsOneWidget);
    expect(find.text('Swipe'), findsOneWidget);

    // Check that repository names are rendered cleanly
    expect(find.text('the void kernel'), findsOneWidget);
    expect(find.text('Mod d abus ar.'), findsOneWidget);
    expect(find.text('pocketstrike-executive-ai'), findsOneWidget);

    // Check cell sizes: height should be single line (~16-25px), NOT 100+px tall
    final cellFinder = find.text('the void kernel');
    final cellSize = tester.getSize(cellFinder);
    expect(cellSize.height, lessThan(35));

    // Check horizontal scroll view exists
    final scrollViews = find.byType(SingleChildScrollView);
    bool hasHorizontalScroll = false;
    for (final s in scrollViews.evaluate()) {
      final w = s.widget as SingleChildScrollView;
      if (w.scrollDirection == Axis.horizontal) {
        hasHorizontalScroll = true;
        break;
      }
    }
    expect(hasHorizontalScroll, isTrue);

    // Test swiping horizontally on the table
    final tableFinder = find.byType(Table);
    expect(tableFinder, findsOneWidget);
    await tester.drag(tableFinder, const Offset(-150, 0), warnIfMissed: false);
    await tester.pumpAndSettle();
  });
}
