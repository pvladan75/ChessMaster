/// What there is to practise, as the server counts it.
///
/// The collection holds 128 distinct endings and grows with every mining run,
/// so this is not a list anybody maintains: the server derives the families and
/// their Serbian names from the material key itself, and the app only draws
/// what it is handed.
///
/// The counts come broken down by rating band as well, which is what lets the
/// picker show an exact total for any combination before it asks for a
/// position. A picker that lets you build an empty query and only says so
/// afterwards is the thing this avoids.
library;

class EloBand {
  const EloBand({required this.id, required this.name});

  final String id;
  final String name;

  factory EloBand.fromJson(Map<String, dynamic> json) => EloBand(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

/// One exact ending: 'KRPvKR', "top i pešak protiv topa", and how many.
class EndgameEnding {
  const EndgameEnding({
    required this.material,
    required this.label,
    required this.count,
    this.bands = const {},
    this.opposite = 0,
  });

  final String material;
  final String label;
  final int count;

  /// How the positions split across the rating bands.
  final Map<String, int> bands;

  /// How many of them have bishops on opposite colours — which the material
  /// key cannot say, so the server reads it from the position.
  final int opposite;

  int countIn(String? bandId) => bandId == null ? count : (bands[bandId] ?? 0);

  factory EndgameEnding.fromJson(Map<String, dynamic> json) => EndgameEnding(
        material: json['material']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        bands: ((json['bands'] as Map?) ?? const {}).map(
          (key, value) =>
              MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        ),
        opposite: (json['opposite'] as num?)?.toInt() ?? 0,
      );
}

/// A family of endings: rook endings, pawn endings, and five more.
class EndgameFamily {
  const EndgameFamily({
    required this.id,
    required this.name,
    required this.count,
    required this.endings,
  });

  final String id;
  final String name;
  final int count;
  final List<EndgameEnding> endings;

  factory EndgameFamily.fromJson(Map<String, dynamic> json) => EndgameFamily(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        endings: ((json['endings'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EndgameEnding.fromJson)
            .toList(),
      );
}

class EndgameCatalog {
  const EndgameCatalog({
    required this.families,
    required this.bands,
    this.oppositeBishops = 0,
  });

  final List<EndgameFamily> families;
  final List<EloBand> bands;

  /// How many positions in the whole collection have opposite bishops. Zero
  /// means the switch is not worth offering.
  final int oppositeBishops;

  bool get isEmpty => families.isEmpty;

  Iterable<EndgameEnding> get allEndings =>
      families.expand((family) => family.endings);

  /// Every ending, selected by default: a picker that starts empty asks the
  /// reader to do work before they can do anything.
  Set<String> get allMaterials =>
      allEndings.map((ending) => ending.material).toSet();

  /// Exactly how many positions a given choice covers.
  ///
  /// [bandId] null means every level. [oppositeOnly] counts the opposite-bishop
  /// positions instead, and ignores the band — the server reports that number
  /// per ending rather than per ending and band, and 43 positions in the whole
  /// collection is not worth a second breakdown.
  int countFor({
    required Set<String> materials,
    String? bandId,
    bool oppositeOnly = false,
  }) {
    var total = 0;
    for (final ending in allEndings) {
      if (!materials.contains(ending.material)) continue;
      total += oppositeOnly ? ending.opposite : ending.countIn(bandId);
    }
    return total;
  }

  /// The filter for a selection, or null when it covers everything.
  String? materialsParamFor(Set<String> materials) {
    if (materials.length >= allMaterials.length) return null;
    final ordered = materials.toList()..sort();
    return ordered.join(',');
  }

  factory EndgameCatalog.fromJson(Map<String, dynamic> json) => EndgameCatalog(
        families: ((json['families'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EndgameFamily.fromJson)
            .toList(),
        bands: ((json['bands'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EloBand.fromJson)
            .toList(),
        oppositeBishops: (json['oppositeBishops'] as num?)?.toInt() ?? 0,
      );
}

/// What the picker sends back: which endings, which level, and whether to keep
/// only the opposite-bishop ones.
///
/// [materialsParam] is already resolved, because only the picker holds the
/// catalog and only the catalog knows whether a selection is all of it. Working
/// that out anywhere further along would mean carrying the catalog there too.
class EndgameChoice {
  const EndgameChoice({
    required this.materials,
    this.materialsParam,
    this.bandId,
    this.oppositeOnly = false,
  });

  final Set<String> materials;

  /// Null when everything is selected: the route reads a missing filter as
  /// "any", and 128 keys in a URL would say the same thing the long way.
  final String? materialsParam;

  final String? bandId;
  final bool oppositeOnly;
}
