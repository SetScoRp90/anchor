import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:home_widget/home_widget.dart';
import 'core/app_initializer.dart';
import 'core/network/connectivity_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/settings/presentation/controllers/theme_preferences_controller.dart';
import 'features/widget/widget_pending_note_provider.dart';

void main() async {
  await initializeApp();
  runApp(const ProviderScope(child: AnchorApp()));
}

class AnchorApp extends ConsumerStatefulWidget {
  const AnchorApp({super.key});

  @override
  ConsumerState<AnchorApp> createState() => _AnchorAppState();
}

class _AnchorAppState extends ConsumerState<AnchorApp> {
  @override
  void initState() {
    super.initState();
    _initWidgetHandling();
  }

  Future<void> _initWidgetHandling() async {
    // Handle cold start: app opened by tapping the widget
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetUri(initialUri);

    // Handle widget taps while app is already running
    HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final noteId = uri.queryParameters['noteId'];
    if (noteId == null || noteId.isEmpty) return;
    ref.read(widgetPendingNoteIdProvider.notifier).state = noteId;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    // Initialize sync manager to listen for connectivity changes
    ref.watch(syncManagerProvider);

    // Navigate to note when widget is tapped and user is already authenticated
    ref.listen(widgetPendingNoteIdProvider, (_, noteId) {
      if (noteId == null) return;
      final isLoggedIn =
          ref.read(authControllerProvider).hasValue &&
          ref.read(authControllerProvider).value != null;
      if (isLoggedIn) {
        ref.read(widgetPendingNoteIdProvider.notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/note/$noteId');
        });
      }
    });

    // Navigate to note after user logs in (widget was tapped while unauthenticated)
    ref.listen(authControllerProvider, (_, authState) {
      if (!authState.hasValue || authState.value == null) return;
      final noteId = ref.read(widgetPendingNoteIdProvider);
      if (noteId != null) {
        ref.read(widgetPendingNoteIdProvider.notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/note/$noteId');
        });
      }
    });

    return MaterialApp.router(
      title: 'Anchor Notes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
    );
  }
}
