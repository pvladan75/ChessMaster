import 'package:flutter/material.dart';

class CategorySelectionHubWidget extends StatelessWidget {
  final Function(String depth) onSelectMatePuzzle;
  final Function(String presetDifficulty) onSelectBasicMate;
  final VoidCallback onSelectWinningPosition;
  final VoidCallback onSelectTactics;
  final VoidCallback onSelectEndgameWin;
  final VoidCallback onSelectEndgameDraw;
  final VoidCallback onSelectBlunderGames;

  const CategorySelectionHubWidget({
    super.key,
    required this.onSelectMatePuzzle,
    required this.onSelectBasicMate,
    required this.onSelectWinningPosition,
    required this.onSelectTactics,
    required this.onSelectEndgameWin,
    required this.onSelectEndgameDraw,
    required this.onSelectBlunderGames,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.deepPurple.shade700,
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Šahovski trener i vežbe',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Izaberite modul za vežbanje taktičkih zagonetki ili matnih završnica.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // CARD 0: Adaptive tactics — listed first because it is the mode
              // that adjusts to the solver, while the ones below are fixed sets.
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                      color: Colors.lightBlueAccent, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.auto_graph,
                              color: Colors.lightBlueAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Taktika po vašoj meri',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Zagonetke iz Lichess baze, birane prema vašem rejtingu i temi '
                        'koju najslabije rešavate. Rejting se prati po svakom motivu posebno.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Započni trening'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: onSelectTactics,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD: Zavrsnice.
              //
              // Placed next to tactics because it is the same kind of thing to a
              // user - a position to solve - even though the material behind it
              // is mined here rather than taken from Lichess. Two buttons, not
              // one: converting a won position and holding a drawn one are
              // different skills, and a child asked to "find the move" without
              // being told which of the two it is has been asked the wrong
              // question.
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.amber, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flag_outlined,
                              color: Colors.amber, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Završnice iz majstorskih partija',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pozicije izdvojene iz partija velemajstora. Za završnice '
                        'sa malo figura ishod je tačan, ne procenjen — priznaje se '
                        'svaki potez koji drži rezultat, a ne samo jedan.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      // Wrap, not Row: two Serbian labels plus icons outgrow a
                      // 360 dp phone, and a release build clips instead of
                      // warning.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Dobij'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: onSelectEndgameWin,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Održi remi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: onSelectEndgameDraw,
                          ),
                          // The same material read as games rather than as
                          // positions: a real ending played badly, walked from
                          // the first mistake to the last.
                          ElevatedButton.icon(
                            icon: const Icon(Icons.history_edu_outlined),
                            label: const Text('Greške iz partija'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: onSelectBlunderGames,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD 1: Zagonetke: Mat u 1, 2 ili 3 poteza
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.sports_esports,
                            color: Colors.tealAccent,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Zagonetke: Mat u 1, 2 ili 3 poteza',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Rešavajte forsiranu matnu sekvencu u traženom broju poteza.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_one),
                            label: const Text('Mat u 1'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectMatePuzzle('1'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_two),
                            label: const Text('Mat u 2'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectMatePuzzle('2'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_3),
                            label: const Text('Mat u 3'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectMatePuzzle('3'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD 2: Vežbajte osnovno matiranje
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: Colors.purpleAccent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.workspace_premium,
                            color: Colors.purpleAccent,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vežbajte osnovno matiranje',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Matirajte protivnika u klasičnim matnim pozicijama protiv Stockfish-a.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.sentiment_satisfied,
                              size: 16,
                            ),
                            label: const Text('Lako'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectBasicMate('easy'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.sentiment_neutral,
                              size: 16,
                            ),
                            label: const Text('Srednje'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectBasicMate('medium'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.sentiment_very_dissatisfied,
                              size: 16,
                            ),
                            label: const Text('Teško'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onSelectBasicMate('hard'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD 3: Pronađite dobitni put
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.amber, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.amberAccent,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pronađite dobitni put',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Igrajte dobitne pozicije do kraja protiv Stockfish-a uz opcioni Blunder Alert.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Započni vežbanje dobitnih pozicija'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: onSelectWinningPosition,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
