// Renders a real screen to PNG with real glyphs, for a look by eye
// (docs/PLAN-EKRANI.md §4.3). Not a test; nothing in the suite imports it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Roboto from test/fonts, and the Material icon font from the SDK when the
/// SDK has it. Call from setUpAll.
///
/// Roboto is strict: it travels with the tests, and a missing file is a
/// checkout without it. The icon font is not, because the CI runner's SDK has
/// no `material_fonts` (both CI runs of 3.10.2026 failed every gate that
/// loaded it in `setUpAll`) — a font read from the machine is a test of the
/// machine. It changes no measurement: an `Icon` is a box of its own size
/// whatever its glyph, so without the font a picture shows squares where the
/// icons are and every rectangle a gate asserts is the same.
Future<void> loadRenderFonts() async {
  final roboto = FontLoader('Roboto');
  for (final n in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf'
  ]) {
    roboto.addFont(Future.value(
        File('test/fonts/$n').readAsBytesSync().buffer.asByteData()));
  }
  await roboto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final iconFile = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (root == null || !iconFile.existsSync()) return;
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(iconFile.readAsBytesSync().buffer.asByteData()));
  await icons.load();
}

/// The app's theme with Roboto named wherever the app leaves the family null.
/// On a device null means the platform's font; in a test it means a font of
/// boxes. Buttons and the app bar take their style whole from the theme, not
/// merged with the ambient one, so they are named here one by one.
ThemeData robotoTheme(ThemeData t) {
  TextStyle f(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(fontFamily: 'Roboto');
  WidgetStateProperty<TextStyle?> p(WidgetStateProperty<TextStyle?>? s) =>
      WidgetStateProperty.resolveWith((st) => f(s?.resolve(st)));
  ButtonStyle b(ButtonStyle? s) =>
      (s ?? const ButtonStyle()).copyWith(textStyle: p(s?.textStyle));
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: t.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: t.appBarTheme.copyWith(
      titleTextStyle: f(t.appBarTheme.titleTextStyle ?? t.textTheme.titleLarge),
      toolbarTextStyle:
          f(t.appBarTheme.toolbarTextStyle ?? t.textTheme.bodyMedium),
    ),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: b(t.elevatedButtonTheme.style)),
    filledButtonTheme:
        FilledButtonThemeData(style: b(t.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: b(t.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: b(t.textButtonTheme.style)),
    chipTheme: t.chipTheme.copyWith(labelStyle: f(t.chipTheme.labelStyle)),
    dialogTheme: t.dialogTheme.copyWith(
      titleTextStyle: f(t.dialogTheme.titleTextStyle ?? t.textTheme.titleLarge),
      contentTextStyle:
          f(t.dialogTheme.contentTextStyle ?? t.textTheme.bodyMedium),
    ),
    tabBarTheme: t.tabBarTheme.copyWith(
      labelStyle: f(t.tabBarTheme.labelStyle),
      unselectedLabelStyle: f(t.tabBarTheme.unselectedLabelStyle),
    ),
  );
}

/// Lets images decode, then writes the boundary under [key] to [path].
Future<void> capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).parent.createSync(recursive: true);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
