import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/agent/ui/agent_run_screen.dart';
import 'package:pocketstrike/features/chat/ui/home_shell.dart';
import 'package:pocketstrike/features/onboarding/onboarding_screen.dart';
import 'package:pocketstrike/features/onboarding/splash_screen.dart';
import 'package:pocketstrike/features/settings/ui/about_export_screen.dart';
import 'package:pocketstrike/features/settings/ui/agent_tools_screen.dart';
import 'package:pocketstrike/features/settings/ui/appearance_settings_screen.dart';
import 'package:pocketstrike/features/settings/ui/cron_tasks_screen.dart';
import 'package:pocketstrike/features/settings/ui/hermes_evolution_screen.dart';
import 'package:pocketstrike/features/settings/ui/local_models_screen.dart';
import 'package:pocketstrike/features/settings/ui/mcp_settings_screen.dart';
import 'package:pocketstrike/features/settings/ui/memory_settings_screen.dart';
import 'package:pocketstrike/features/settings/ui/model_params_screen.dart';
import 'package:pocketstrike/features/settings/ui/provider_edit_screen.dart';
import 'package:pocketstrike/features/settings/ui/providers_settings_screen.dart';
import 'package:pocketstrike/features/settings/ui/settings_screen.dart';
import 'package:pocketstrike/features/gallery/ui/gallery_screen.dart';
import 'package:pocketstrike/features/settings/ui/storage_settings_screen.dart';
import 'package:pocketstrike/features/settings/ui/telegram_settings_screen.dart';

/// App routes.
abstract class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const chat = '/chat';
  static const gallery = '/gallery';
  static const settings = '/settings';
  static const settingsProviders = '/settings/providers';
  static const settingsProviderEdit = '/settings/providers/edit';
  static const settingsLocalModels = '/settings/local-models';
  static const settingsModels = '/settings/models';
  static const settingsAppearance = '/settings/appearance';
  static const settingsMcp = '/settings/mcp';
  static const settingsTelegram = '/settings/telegram';
  static const settingsStorage = '/settings/storage';
  static const settingsTools = '/settings/tools';
  static const settingsMemory = '/settings/memory';
  static const settingsHermes = '/settings/hermes';
  static const settingsTasks = '/settings/tasks';
  static const settingsAbout = '/settings/about';
  static const agentRun = '/agent-run';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      final onSplash = state.matchedLocation == AppRoutes.splash;
      if (!onboardingDone && state.matchedLocation != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (onboardingDone && onSplash) return AppRoutes.chat;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:id',
        builder: (context, state) =>
            HomeShell(conversationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsProviders,
        builder: (context, state) => const ProvidersSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsProviderEdit,
        builder: (context, state) =>
            ProviderEditScreen(configId: state.extra as String?),
      ),
      GoRoute(
        path: AppRoutes.settingsLocalModels,
        builder: (context, state) => const LocalModelsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsModels,
        builder: (context, state) => const ModelParamsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAppearance,
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsMcp,
        builder: (context, state) => const McpSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsTelegram,
        builder: (context, state) => const TelegramSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsStorage,
        builder: (context, state) => const StorageSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsTools,
        builder: (context, state) => const AgentToolsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsMemory,
        builder: (context, state) => const MemorySettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsHermes,
        builder: (context, state) => const HermesEvolutionScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsTasks,
        builder: (context, state) => const CronTasksScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAbout,
        builder: (context, state) => const AboutExportScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.agentRun}/:id',
        builder: (context, state) =>
            AgentRunScreen(runId: state.pathParameters['id']!),
      ),
    ],
  );
});
