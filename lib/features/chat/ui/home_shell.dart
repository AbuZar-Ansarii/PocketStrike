import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversations/application/conversations_controller.dart';
import 'chat_screen.dart';
import 'widgets/app_drawer.dart';

/// Root screen: sidebar drawer + chat surface.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    _syncConversation();
  }

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _syncConversation();
    }
  }

  void _syncConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(currentConversationIdProvider.notifier).state =
          widget.conversationId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(),
      body: ChatScreen(),
    );
  }
}
