import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour-vision simulation and contrast measurement, shared by the tests that
/// have to prove a board is legible rather than claim it.
///
/// This exists because the one person who watches this app running is
/// colourblind, and because the app's users are Serbian children — roughly one
/// boy in twelve has a red-green deficiency. Neither of those is a reason to
/// stop using colour; both are reasons that colour must never be the **only**
/// channel carrying a meaning. A number is the only way to know, and eyes are
/// exactly what is not available here.
///
/// The simulation is Viénot, Brettel & Mollon (1999), "Digital video colourmaps
/// for checking the legibility of displays by dichromats" — the single-plane
/// projection in LMS, collapsed into one 3×3 matrix per deficiency and applied
/// in **linear** RGB. It models a dichromat: someone with the cone class
/// missing entirely, which is the worst case rather than the common one.
/// Anomalous trichromacy (the far more frequent condition) sits somewhere
/// between this and normal vision, so a pairing that survives here survives it.
///
/// **Tritanopia is deliberately absent.** The Viénot simplification is accurate
/// for protan and deutan and is known to be poor for tritan — the paper says so
/// itself — and a number produced by a model that does not hold is worse than
/// no number, because it will be believed. If tritanopia is ever wanted here it
/// needs the full two-plane Brettel construction, not another matrix pasted
/// under this comment.
enum ColorVision {
  /// Ordinary trichromatic vision. The identity transform, present so a loop
  /// can run every deficiency and normal vision through the same code path.
  normal('normalan vid'),

  /// No long-wavelength ("red") cones.
  protanopia('protanopija'),

  /// No medium-wavelength ("green") cones.
  deuteranopia('deuteranopija');

  const ColorVision(this.label);

  /// Serbian, because it is what a failure message is read in.
  final String label;
}

/// sRGB transfer function, undone. WCAG's own definition, and the same curve
/// [relativeLuminance] uses — the simulation has to happen in linear light or
/// the matrix is being applied to gamma-encoded numbers, which is a common way
/// to get a plausible-looking wrong answer.
double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) {
  final v = c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return v.clamp(0.0, 1.0).toDouble();
}

/// Row-major 3×3, operating on linear RGB.
const Map<ColorVision, List<double>> _matrices = {
  ColorVision.protanopia: [
    0.11238, 0.88762, 0.00000, //
    0.11238, 0.88762, 0.00000, //
    0.00401, -0.00401, 1.00000, //
  ],
  ColorVision.deuteranopia: [
    0.29275, 0.70725, 0.00000, //
    0.29275, 0.70725, 0.00000, //
    -0.02234, 0.02234, 1.00000, //
  ],
};

/// [color] as a dichromat of type [vision] would see it.
///
/// Alpha is carried through untouched: this converts a colour, it does not
/// composite one. Anything drawn semi-transparent has to be flattened with
/// [over] **first**, because 45% amber over a tan square and 45% amber over
/// walnut are two different colours and only one of them is on the screen.
Color simulate(Color color, ColorVision vision) {
  final matrix = _matrices[vision];
  if (matrix == null) return color;

  final r = _toLinear(color.r);
  final g = _toLinear(color.g);
  final b = _toLinear(color.b);

  return Color.from(
    alpha: color.a,
    red: _toSrgb(matrix[0] * r + matrix[1] * g + matrix[2] * b),
    green: _toSrgb(matrix[3] * r + matrix[4] * g + matrix[5] * b),
    blue: _toSrgb(matrix[6] * r + matrix[7] * g + matrix[8] * b),
  );
}

/// [fg] composited onto opaque [bg], which is what the screen actually shows.
///
/// The last-move marker is a 45% fill, so every honest measurement of it is a
/// measurement of this result rather than of the token.
Color over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// WCAG 2.x relative luminance.
double relativeLuminance(Color c) =>
    0.2126 * _toLinear(c.r) + 0.7152 * _toLinear(c.g) + 0.0722 * _toLinear(c.b);

/// WCAG 2.x contrast ratio, 1.0 to 21.0.
double contrast(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The contrast between two colours as [vision] would see them.
///
/// Note what this does and does not capture. It answers "is there still a
/// **luminance** difference once the hue difference is gone", which is the
/// question that decides whether a marker survives. It does not answer "are
/// these two colours distinguishable", because two colours can differ in
/// luminance and still be an unpleasant pair. Contrast is a floor, not a
/// verdict.
double contrastAs(Color a, Color b, ColorVision vision) =>
    contrast(simulate(a, vision), simulate(b, vision));

/// The worst contrast [a] and [b] have across normal vision and both modelled
/// deficiencies — the number that decides whether something is legible for
/// everybody rather than for most people.
double worstContrast(Color a, Color b) {
  var worst = double.infinity;
  for (final vision in ColorVision.values) {
    final value = contrastAs(a, b, vision);
    if (value < worst) worst = value;
  }
  return worst;
}

/// The deficiency that produced [worstContrast], for a failure message that
/// says which eyes it fails for.
ColorVision worstVisionFor(Color a, Color b) {
  var worst = double.infinity;
  var which = ColorVision.normal;
  for (final vision in ColorVision.values) {
    final value = contrastAs(a, b, vision);
    if (value < worst) {
      worst = value;
      which = vision;
    }
  }
  return which;
}
