import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/folder_panel/data/bookmarks_notifier.dart';
import 'features/folder_panel/data/folder_panel_state_notifier.dart';
import 'features/online_lookup/data/providers/lookup_settings_provider.dart';
import 'features/settings/data/models/general_settings.dart';
import 'features/settings/data/providers/settings_providers.dart';
import 'features/tag_editor/data/providers/column_config_provider.dart';
import 'features/tag_editor/data/providers/editor_state_provider.dart';
import 'features/tag_editor/data/providers/folder_loading_provider.dart';
import 'features/tag_editor/data/providers/recent_folders_provider.dart';
import 'features/tag_editor/data/providers/recursive_loading_provider.dart';
import 'features/tag_editor/presentation/pages/home_page.dart';
import 'features/tag_editor/presentation/widgets/keyboard_shortcuts.dart';
import 'shared/widgets/unsaved_changes_guard.dart';

class OpenTagEditorApp extends ConsumerStatefulWidget {
  const OpenTagEditorApp({super.key});

  @override
  ConsumerState<OpenTagEditorApp> createState() => _OpenTagEditorAppState();
}

class _OpenTagEditorAppState extends ConsumerState<OpenTagEditorApp>
    with WindowListener {
  Timer? _geometrySaveTimer;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // Load all persisted settings asynchronously at startup.
    Future.microtask(() async {
      await ref.read(generalSettingsProvider.notifier).loadFromPrefs();
      ref.read(tagWritingSettingsProvider.notifier).loadFromPrefs();
      ref.read(renamingSettingsProvider.notifier).loadFromPrefs();
      ref.read(lookupSettingsProvider.notifier).loadFromPrefs();
      ref.read(recentFoldersProvider.notifier).loadFromPrefs();
      ref.read(recursiveLoadingProvider.notifier).loadFromPrefs();
      ref.read(columnConfigProvider.notifier).loadFromPrefs();
      ref.read(folderPanelStateProvider.notifier).loadFromPrefs();
      ref.read(bookmarksProvider.notifier).loadFromPrefs();

      _maybeReopenLastFolder();
    });

    // Listen for tag panel open/close changes and sync to window state.
    ref.listenManual(tagPanelOpenProvider, (previous, next) {
      ref.read(windowStateProvider.notifier).setTagPanelOpen(next);
    });

    // Reactively update window title to reflect dirty state.
    ref.listenManual(hasUnsavedChangesProvider, (previous, next) {
      final title = next ? '* Open Tag Editor' : 'Open Tag Editor';
      windowManager.setTitle(title);
    });

    // Set initial title (clean state at startup).
    windowManager.setTitle('Open Tag Editor');
  }

  @override
  void dispose() {
    _geometrySaveTimer?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResized() => _scheduleGeometrySave();

  @override
  void onWindowMoved() => _scheduleGeometrySave();

  @override
  Future<void> onWindowClose() async {
    final hasDirty = ref.read(hasUnsavedChangesProvider);
    if (!hasDirty) {
      await _saveGeometryAndClose();
      return;
    }

    if (!mounted) {
      await windowManager.destroy();
      return;
    }

    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: ref,
      clearUndoOnDiscard: false,
    );

    if (proceed) {
      await _saveGeometryAndClose();
    }
    // If cancelled, do nothing — window stays open.
  }

  /// Saves the current window geometry and destroys the window.
  Future<void> _saveGeometryAndClose() async {
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      ref
          .read(windowStateProvider.notifier)
          .updateGeometry(
            size.width.round(),
            size.height.round(),
            position.dx.round(),
            position.dy.round(),
          );
    } catch (_) {
      // Best-effort geometry save.
    }
    await windowManager.destroy();
  }

  /// Debounces geometry saves so we don't write to SharedPreferences on
  /// every frame during a drag. Saves 500ms after the last move/resize event.
  void _scheduleGeometrySave() {
    _geometrySaveTimer?.cancel();
    _geometrySaveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();
        ref
            .read(windowStateProvider.notifier)
            .updateGeometry(
              size.width.round(),
              size.height.round(),
              position.dx.round(),
              position.dy.round(),
            );
      } catch (_) {
        // Best-effort
      }
    });
  }

  /// Reloads the last loaded folder if the setting is enabled and the
  /// folder still exists on disk.
  void _maybeReopenLastFolder() {
    final generalSettings = ref.read(generalSettingsProvider);
    if (!generalSettings.reopenLastFolder) return;

    final windowState = ref.read(windowStateProvider);
    final lastFolder = windowState.lastFolderPath;
    if (lastFolder == null || lastFolder.isEmpty) return;

    // Check if the folder still exists.
    final dir = Directory(lastFolder);
    if (!dir.existsSync()) {
      // Clear the persisted path since it no longer exists.
      ref.read(windowStateProvider.notifier).setLastFolderPath(null);
      return;
    }

    // Trigger folder loading after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = FolderLoadingService(ref.read);
      service.loadFolder(context, lastFolder);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(generalSettingsProvider);
    final themeMode = settings.themeMode;

    return MaterialApp(
      title: 'Open Tag Editor',
      debugShowCheckedModeBanner: false,
      theme: settings.highContrast
          ? AppTheme.highContrastLight
          : AppTheme.light,
      darkTheme: settings.highContrast
          ? AppTheme.highContrastDark
          : AppTheme.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      // Applies the user's text scale on top of whatever the platform has
      // already set, rather than replacing it, so the two compose instead of
      // one silently overriding the other.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: GeneralSettings.minUiScale,
              maxScaleFactor: GeneralSettings.maxUiScale,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const EditorKeyboardShortcuts(child: HomePage()),
    );
  }
}
