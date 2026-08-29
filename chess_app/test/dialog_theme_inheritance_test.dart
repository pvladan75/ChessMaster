import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// app_colors.dart re-exports app_theme.dart; importing both is an
// unnecessary_import info, which would move analyze off its 29-line baseline.
import 'package:chess_app/theme/app_colors.dart';

/// A `Dialog` with no `backgroundColor` must take `dialogTheme`'s.
///
/// Batch 14 deleted `backgroundColor: colors.surface` from four dialogs that
/// were writing again what `app_theme.dart` already declares. Nothing in the
/// suite could tell that apart from deleting a *necessary* property: both
/// leave 777 tests green, both leave `flutter analyze` at its baseline, and
/// the contrast gate measures foregrounds against whatever background it is
/// told about, not against the one Flutter actually paints. The only check
/// that existed was reading the diff and knowing the framework.
///
/// So this is the check. If a future Flutter drops the fallback, or somebody
/// removes `dialogTheme.backgroundColor`, these fail here rather than showing
/// up as a dialog that has quietly become the wrong colour on a phone.
void main() {
  const colors = AppColorTokens.dark;

  Future<Color?> dialogBackground(WidgetTester tester, Widget dialog,
      {ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => dialog,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The Material that Dialog builds for its surface is the first one inside
    // it. Reading Dialog.backgroundColor would only read back the property
    // this test exists to prove is unnecessary; what matters is the colour
    // that ends up painted.
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Material),
          )
          .first,
    );
    return material.color;
  }

  testWidgets('a Dialog with no backgroundColor paints dialogTheme surface',
      (tester) async {
    final painted = await dialogBackground(
      tester,
      const Dialog(child: SizedBox(width: 100, height: 100)),
    );
    expect(painted, colors.surface);
  });

  testWidgets('an AlertDialog with no backgroundColor paints the same',
      (tester) async {
    final painted = await dialogBackground(
      tester,
      const AlertDialog(content: Text('x')),
    );
    expect(painted, colors.surface);
  });

  testWidgets('the theme is where that colour comes from', (tester) async {
    // If this ever fails, the two tests above are passing for the wrong
    // reason -- a framework default that happens to match, rather than the
    // app's own theme.
    expect(AppTheme.dark.dialogTheme.backgroundColor, colors.surface);
  });

  testWidgets('the dialog follows dialogTheme, not a coincidence',
      (tester) async {
    // The two tests above would pass even with dialogTheme.backgroundColor
    // deleted, because Flutter then falls back to ColorScheme.surface and this
    // theme builds both from the same token -- they agree by construction.
    // Proved by mutation: removing the property left them green. So this one
    // moves dialogTheme somewhere the fallback cannot reach and checks the
    // dialog goes with it.
    final moved = AppTheme.dark.copyWith(
      dialogTheme: AppTheme.dark.dialogTheme.copyWith(
        backgroundColor: colors.danger,
      ),
    );
    final painted = await dialogBackground(
      tester,
      const Dialog(child: SizedBox(width: 100, height: 100)),
      theme: moved,
    );
    expect(painted, colors.danger);
    expect(painted, isNot(AppTheme.dark.colorScheme.surface));
  });
}
