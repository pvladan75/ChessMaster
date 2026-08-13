import 'package:flutter/material.dart';

/// The "Biblioteka" tab: shortcuts into the Studio (empty board) and the
/// Analysis board. Stateless — both actions just navigate.
class HomeBibliotekaTab extends StatelessWidget {
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenAnalysis;

  const HomeBibliotekaTab({
    super.key,
    required this.onOpenStudio,
    required this.onOpenAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.library_books, color: Colors.tealAccent, size: 28),
                          SizedBox(width: 12),
                          Text('Biblioteka Pozicija i Lekcija', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upravljajte vašim sačuvanim pozicijama, PGN fajlovima i kursevima.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text('Otvori Šahovski Studio sa praznom tablom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: onOpenStudio,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: Colors.deepPurple.shade900.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.biotech, color: Colors.tealAccent, size: 28),
                          SizedBox(width: 12),
                          Text('Tabla za Analizu 🔬', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Slobodna šahovska tabla za duboku analizu, unos varijacija za obe strane, rad sa PGN/FEN pozicijama i beleženje komentara i NAG simbola.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.biotech),
                          label: const Text('Otvori Tablu za Analizu', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: onOpenAnalysis,
                        ),
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
