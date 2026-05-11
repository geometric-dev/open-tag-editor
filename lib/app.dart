import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/tag_editor/presentation/pages/home_page.dart';
import 'features/tag_editor/presentation/widgets/keyboard_shortcuts.dart';

class OpenTagEditorApp extends ConsumerWidget {
  const OpenTagEditorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Open Tag Editor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const EditorKeyboardShortcuts(
        child: HomePage(),
      ),
    );
  }
}
