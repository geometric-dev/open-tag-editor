/// One group of keyboard shortcuts in the help dialog.
class ShortcutGroup {
  const ShortcutGroup(this.title, this.shortcuts);

  final String title;

  /// (display keys, what it does)
  final List<(String, String)> shortcuts;
}

/// The shortcut reference shown in Help ▸ Keyboard Shortcuts.
///
/// Hand-maintained rather than derived from the bindings: a
/// `CallbackShortcuts` map is keyed by `LogicalKeyboardKey` and cannot render
/// a readable "Ctrl + Shift + Home" without a second mapping anyway, so the
/// alternative is either a table that can drift or nothing. Grouping and
/// wording are the parts a user actually reads.
class ShortcutReference {
  const ShortcutReference._();

  static const groups = <ShortcutGroup>[
    ShortcutGroup('Files', [
      ('Ctrl + O', 'Open folder'),
      ('Ctrl + Shift + O', 'Open individual files'),
      ('Ctrl + G', 'Quick folder switcher'),
      ('Alt + ← / →', 'Previous / next sibling folder'),
      ('F5', 'Re-read tags from disk'),
      ('Ctrl + A', 'Select all files'),
    ]),
    ShortcutGroup('Editing', [
      ('F2 or double-click', 'Edit the focused cell'),
      ('Type a character', 'Start editing with that character'),
      ('Enter', 'Commit the edit and open the tag panel'),
      ('Tab / Shift + Tab', 'Move to the next / previous cell'),
      ('Esc', 'Cancel the edit or clear the focus'),
    ]),
    ShortcutGroup('Selecting', [
      ('↑ / ↓', 'Move one row'),
      ('Shift + ↑ / ↓', 'Extend the selection'),
      ('Ctrl + ↑ / ↓', 'Move focus without changing the selection'),
      ('Ctrl + Space', 'Add or remove the focused row'),
      ('Page Up / Page Down', 'Move a page'),
      ('Home / End', 'First / last row'),
      ('Ctrl + Shift + Home / End', 'Extend to first / last row'),
      ('Click + drag', 'Select a range'),
      ('Ctrl + click', 'Add a file to the selection'),
      ('Delete', 'Remove the selected files from the list'),
    ]),
    ShortcutGroup('Saving', [
      ('Ctrl + S', 'Save tags to disk'),
      ('Ctrl + Z', 'Undo'),
      ('Ctrl + Y or Ctrl + Shift + Z', 'Redo'),
    ]),
    ShortcutGroup('Windows', [
      (
        'Right-click a column header',
        'Show or hide columns, reorder, reset widths',
      ),
      ('Drag a column header', 'Reorder columns'),
      ('Drag the right edge of a header', 'Resize a column'),
      ('Double-click a column edge', 'Auto-fit the column'),
    ]),
  ];

  /// Total number of documented shortcuts, for the dialog summary.
  static int get total =>
      groups.fold(0, (sum, group) => sum + group.shortcuts.length);
}
