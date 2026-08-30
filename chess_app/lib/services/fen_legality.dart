import 'package:chess/chess.dart' as chess;

/// Da li je FEN ne samo ispravno napisan nego i **moguca partija**.
///
/// `chess.Chess.validate_fen` proverava samo zapis: broj polja, dozvoljena
/// slova, ispravnu rokadu i en-passant. Ne proverava nijedno pravilo igre — u
/// njemu se rec „kralj" ne pojavljuje nijednom. Pozicija bez kralja se zato
/// uredno parsira, prodje kao ispravna, stigne do motora, i tu aplikacija pukne.
///
/// Nadjeno uzivo 30.8.2026: pozicija se rucno postavi bez kralja, uveze u
/// Studio, ukljuci se motor — i aplikacija se srusi. Kvar nije u motoru nego
/// ovde: pusteno mu je nesto sto nije sah.
///
/// Vraca `null` kad je sve u redu, ili poruku na srpskom kad nije.
String? fenIllegalReason(String fen) {
  final tekst = fen.trim();
  if (tekst.isEmpty) return 'Nema FEN zapisa.';

  // Prvo zapis, jer sve ispod pretpostavlja da se moze procitati.
  try {
    final provera = chess.Chess.validate_fen(tekst);
    if (provera['valid'] != true) return 'Neispravan FEN format.';
  } catch (_) {
    return 'Neispravan FEN format.';
  }

  final polja = tekst.split(RegExp(r'\s+'));
  final tabla = polja.first;

  // Tacno jedan kralj svake boje. Ni nijedan ni dva — dva bela kralja su za
  // motor jednako nemoguca kao nijedan, samo se rusi na drugom mestu.
  final beli = 'K'.allMatches(tabla).length;
  final crni = 'k'.allMatches(tabla).length;
  if (beli == 0 && crni == 0) return 'Na tabli nema kraljeva.';
  if (beli == 0) return 'Nedostaje beli kralj.';
  if (crni == 0) return 'Nedostaje crni kralj.';
  if (beli > 1) return 'Na tabli je vise od jednog belog kralja.';
  if (crni > 1) return 'Na tabli je vise od jednog crnog kralja.';

  // Pesak na prvom ili poslednjem redu ne moze da nastane u partiji: do osmog
  // reda stize samo da bi se odmah promovisao.
  final redovi = tabla.split('/');
  if (redovi.length == 8) {
    for (final r in [0, 7]) {
      if (redovi[r].contains('P') || redovi[r].contains('p')) {
        return 'Pesak ne moze da stoji na ${r == 0 ? 'osmom' : 'prvom'} redu.';
      }
    }
  }

  // Strana koja *nije* na potezu ne sme vec da bude u sahu: to bi znacilo da je
  // prethodni potez ostavio kralja napadnutim, sto nijedna partija ne moze da
  // proizvede. Motor takvu poziciju ne prihvata.
  try {
    final igra = chess.Chess.fromFEN(tekst);
    final naPotezu = igra.turn;
    final protivnik =
        naPotezu == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    if (igra.king_attacked(protivnik)) {
      return 'Strana koja nije na potezu je u sahu — takva pozicija ne moze da nastane.';
    }
  } catch (_) {
    return 'Pozicija ne moze da se procita.';
  }

  return null;
}

/// Kratka provera, za mesta koja hoce samo da/ne.
bool isFenLegal(String fen) => fenIllegalReason(fen) == null;
