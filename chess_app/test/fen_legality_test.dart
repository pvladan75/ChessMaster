import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/fen_legality.dart';

/// Da li je pozicija moguca partija, a ne samo ispravno napisan zapis.
///
/// Nadjeno uzivo 30.8.2026: pozicija se rucno postavi bez kralja, uveze u
/// Studio, ukljuci se motor, i aplikacija se srusi. Dotadasnja provera je bila
/// `chess.Chess.fromFEN` u try/catch — a to cita zapis, ne pravila. Test ispod
/// prvo dokazuje bas to: biblioteka takvu poziciju proglasava ispravnom.
void main() {
  const pocetna = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('ispravna pozicija prolazi', () {
    expect(fenIllegalReason(pocetna), isNull);
    expect(isFenLegal('8/8/4k3/8/4P3/4K3/8/8 w - - 0 1'), isTrue);
  });

  test('pozicija bez kralja se odbija, i kaze se kog kralja nema', () {
    // Ovo je tacno onaj slucaj koji je rusio aplikaciju.
    expect(fenIllegalReason('8/8/8/8/4P3/8/8/8 w - - 0 1'),
        contains('nema kraljeva'));
    expect(fenIllegalReason('8/8/4k3/8/4P3/8/8/8 w - - 0 1'),
        contains('beli kralj'));
    expect(fenIllegalReason('8/8/8/8/4P3/4K3/8/8 w - - 0 1'),
        contains('crni kralj'));
  });

  test('dva kralja iste boje su isto tako nemoguca', () {
    // Za motor jednako neupotrebljivo kao nijedan, samo puca na drugom mestu.
    expect(fenIllegalReason('8/8/4k3/8/8/4K1K1/8/8 w - - 0 1'),
        contains('belog kralja'));
  });

  test('pesak ne moze na prvom ni na osmom redu', () {
    expect(fenIllegalReason('P3k3/8/8/8/8/8/8/4K3 w - - 0 1'),
        contains('osmom redu'));
    expect(fenIllegalReason('4k3/8/8/8/8/8/8/p3K3 w - - 0 1'),
        contains('prvom redu'));
  });

  test('strana koja nije na potezu ne sme da bude u sahu', () {
    // Beli je na potezu, a crni kralj je vec napadnut: to znaci da je prethodni
    // potez ostavio kralja pod udarom, sto nijedna partija ne moze da proizvede.
    expect(fenIllegalReason('4k3/8/8/8/8/8/8/R3K3 w - - 0 1'), isNull,
        reason: 'top jos ne napada kralja');
    expect(fenIllegalReason('R3k3/8/8/8/8/8/8/4K3 w - - 0 1'),
        contains('nije na potezu'));
  });

  test('prazan i pokvaren zapis se odbijaju bez pucanja', () {
    expect(fenIllegalReason(''), isNotNull);
    expect(fenIllegalReason('   '), isNotNull);
    expect(fenIllegalReason('ovo nije fen'), isNotNull);
    expect(fenIllegalReason('8/8/8/8/8/8/8/8 w - - 0 1'), isNotNull);
  });
}
