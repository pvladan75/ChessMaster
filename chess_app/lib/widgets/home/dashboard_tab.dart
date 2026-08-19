import 'package:flutter/material.dart';

import 'package:chess_app/services/server_status_service.dart';

/// The "Početna" tab: welcome header, session shortcuts, account stats and
/// the recordings list. Purely presentational — [HomeScreen] owns fetching
/// and mutating everything shown here.
class HomeDashboardTab extends StatelessWidget {
  final String userName;
  final TextEditingController codeController;
  final Map<String, dynamic>? userStats;
  final List<dynamic> recordings;
  final bool isLoadingRecordings;
  final VoidCallback onCreateSessionTap;
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenReviews;

  /// Positions waiting to be reviewed; drives the badge.
  final int dueReviewCount;
  final ValueChanged<String> onJoinRoom;
  final VoidCallback onRefreshRecordings;
  final ValueChanged<int> onOpenReplay;

  const HomeDashboardTab({
    super.key,
    required this.userName,
    required this.codeController,
    required this.userStats,
    required this.recordings,
    required this.isLoadingRecordings,
    required this.onCreateSessionTap,
    required this.onOpenStudio,
    required this.onOpenAssignments,
    required this.onOpenReviews,
    this.dueReviewCount = 0,
    required this.onJoinRoom,
    required this.onRefreshRecordings,
    required this.onOpenReplay,
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
              // Welcome Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dobrodošli, $userName!',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            // The greeting proves the phone remembers you and
                            // nothing else. Said alone, with the backend off, it
                            // reads as "connected" — so when it is not, that is
                            // stated right underneath rather than left to be
                            // discovered when something fails to save.
                            const _ConnectionNotice(),
                            const SizedBox(height: 4),
                            Text(
                              'Spremite se za šahovski čas, rešavajte zagonetke ili analizirajte pozicije.',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Cards Grid (Multiplayer Session & Studio)
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.teal, width: 1.5),
                      ),
                      child: InkWell(
                        onTap: onCreateSessionTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.video_call,
                                  size: 36, color: Colors.tealAccent),
                              SizedBox(height: 12),
                              Text('Nova Sesija',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.tealAccent)),
                              SizedBox(height: 4),
                              Text(
                                  'Pokrenite čas kao Host ili zakažite termin za učenike.',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                            color: Colors.deepPurpleAccent, width: 1.5),
                      ),
                      child: InkWell(
                        onTap: onOpenStudio,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.dashboard,
                                  size: 36, color: Colors.purpleAccent),
                              SizedBox(height: 12),
                              Text('Šahovski Studio',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purpleAccent)),
                              SizedBox(height: 4),
                              Text(
                                  'Samostalni rad, FEN postavljanje, PGN i Stockfish analiza.',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Homework. Sits directly under the session shortcuts because for
              // a student it is the reason to open the app between lessons.
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                      color: Colors.lightBlueAccent, width: 1.5),
                ),
                child: InkWell(
                  onTap: onOpenAssignments,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.assignment_turned_in,
                            size: 32, color: Colors.lightBlueAccent),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Moji zadaci',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Vežbe koje vam je trener zadao i vaš napredak po temama.',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Spaced repetition. Shown even at zero so the student learns the
              // feature exists before anything is due; the badge is what pulls
              // them back on the days it is not.
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: dueReviewCount > 0
                        ? Colors.orangeAccent
                        : Colors.grey.shade700,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: onOpenReviews,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Badge(
                          isLabelVisible: dueReviewCount > 0,
                          label: Text('$dueReviewCount'),
                          child: Icon(
                            Icons.repeat,
                            size: 32,
                            color: dueReviewCount > 0
                                ? Colors.orangeAccent
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ponavljanje',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: dueReviewCount > 0
                                      ? Colors.orangeAccent
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dueReviewCount > 0
                                    ? '$dueReviewCount ${dueReviewCount == 1 ? 'pozicija čeka' : 'pozicija čeka'} na ponavljanje.'
                                    : 'Pozicije iz lekcija vraćaju se na ponavljanje kad im dođe vreme.',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Join Room Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Unesite kod sobe (npr. 123456)',
                            prefixIcon: Icon(Icons.vpn_key),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Pridruži se'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                        onPressed: () {
                          final code = codeController.text.trim();
                          if (code.isNotEmpty) onJoinRoom(code);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resource Usage Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.pie_chart, color: Colors.tealAccent),
                              SizedBox(width: 8),
                              Text('Statistika naloga',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Chip(
                            label: Text(
                              userStats?['account_type'] == 'premium'
                                  ? 'PREMIUM'
                                  : 'FREE',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            backgroundColor:
                                userStats?['account_type'] == 'premium'
                                    ? Colors.amber.withValues(alpha: 0.3)
                                    : Colors.teal.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark, color: Colors.teal),
                        title: const Text('Sačuvane lekcije / pozicije',
                            style: TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${userStats?['savedLessonsCount'] ?? 0} / ${userStats?['limits']?['maxSavedLessons'] == -1 ? '∞' : (userStats?['limits']?['maxSavedLessons'] ?? 20)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.video_camera_front,
                            color: Colors.blueAccent),
                        title: const Text('Kreirano sesija u tekućem mesecu',
                            style: TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${userStats?['monthlySessionsCount'] ?? 0} / ${userStats?['limits']?['maxMonthlySessions'] == -1 ? '∞' : (userStats?['limits']?['maxMonthlySessions'] ?? 5)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recordings Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.video_library,
                                  color: Colors.deepPurpleAccent),
                              SizedBox(width: 8),
                              Text('Snimljeni časovi (Replay)',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: onRefreshRecordings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isLoadingRecordings)
                        const Center(child: CircularProgressIndicator())
                      else if (recordings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                              child: Text('Nemate sačuvanih snimaka.',
                                  style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recordings.length,
                          separatorBuilder: (ctx, idx) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final rec = recordings[idx];
                            final title = rec['title'] ?? 'Snimljena sesija';
                            final dateStr = DateTime.parse(rec['created_at'])
                                .toLocal()
                                .toString()
                                .substring(0, 16);
                            final durationSec = rec['duration'] ?? 0;
                            final durationMin =
                                (durationSec / 60).toStringAsFixed(1);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child:
                                    Icon(Icons.play_arrow, color: Colors.white),
                              ),
                              title: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              subtitle: Text('$dateStr • $durationMin min',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              trailing: ElevatedButton.icon(
                                icon: const Icon(Icons.movie, size: 14),
                                label: const Text('Pusti',
                                    style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    foregroundColor: Colors.white),
                                onPressed: () => onOpenReplay(rec['id'] as int),
                              ),
                            );
                          },
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

/// Says so when being signed in currently buys nothing.
///
/// Listens rather than reading once: the check finishes after this screen is
/// first built, and a notice that arrives a second late is still the truth.
class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ServerStatusService.instance,
      builder: (context, _) {
        final service = ServerStatusService.instance;
        if (!service.hasProblem) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                service.status == ServerStatus.expired
                    ? Icons.lock_clock
                    : Icons.cloud_off,
                size: 14,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  service.message,
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 11.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
