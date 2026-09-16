# Frozen vocabulary: Tutorijal / Čas

Phase 0 of [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md), frozen 6.9.2026 by the owner.
**This table is the contract for batch A.** The worker applies rows; it does not
decide them. A string that is not in a table below is not touched, and a row
whose replacement looks wrong is reported, not improved.

Precedent and reason: `TABELA-RECNIK-2026-09.md` worked because the judgement
happened *before* the batch. Where a sweep decides as it goes, it decides
differently in the fortieth file than in the first.

## The two words

| word | what it names | how a child meets it |
|---|---|---|
| **Tutorijal** | the artefact a trainer writes and a student walks alone: steps, lines, questions | „otvori tutorijal" |
| **Čas** | the live session in a room, with a trainer and a board they share | „uđi u čas" |

They were one word until today, and that is the whole problem: „lekcija" meant
both, so „Poziv na lekciju" (a room opening now) and „Zadaj lekciju" (homework
for Thursday) read as the same event.

**Grammar note for the worker.** „Tutorijal" is masculine, „lekcija" feminine —
so the case endings and every agreeing adjective change with the noun, and a
mechanical find-and-replace produces „Ova tutorijal nema nijedan korak". Every
replacement below is written out in full for exactly that reason. Where a row's
replacement reads oddly in context, **report it and stop** rather than inventing
a third phrasing.

## Table A — app strings that become *Tutorijal*

Paths relative to `chess_app/lib/`. Line numbers are from `master` at
6.9.2026 and will drift; match on the current string, not the line.

| file | line | now | becomes |
|---|---|---|---|
| features/analysis_studio/screens/analysis_studio_screen.dart | 269 | `Uredi korake lekcije` | `Uredi korake tutorijala` |
| " | 1165 | `Koju lekciju uređuješ?` | `Koji tutorijal uređuješ?` |
| " | 1187 | `Lekcija nije pronađena.` | `Tutorijal nije pronađen.` |
| " | 1196 | `Koraci lekcije` | `Koraci tutorijala` |
| " | 1339 | `Korak uspešno dodat u lekciju.` | `Korak uspešno dodat u tutorijal.` |
| features/assignments/screens/lesson_viewer_screen.dart | 572 | `Ova lekcija nema nijedan korak.` | `Ovaj tutorijal nema nijedan korak.` |
| features/assignments/screens/my_assignments_screen.dart | 78 | `Ova lekcija više nije dostupna.` | `Ovaj tutorijal više nije dostupan.` |
| features/assignments/screens/student_progress_screen.dart | 118 | `Lekcija je poslata učeniku.` | `Tutorijal je poslat učeniku.` |
| " | 216 | `Zadaj lekciju` | `Zadaj tutorijal` |
| features/assignments/services/assignment_api_service.dart | 124 | `Lekcija nije zadata.` | `Tutorijal nije zadat.` |
| features/assignments/widgets/assign_lesson_dialog.dart | 77 | `Ne mogu da učitam lekcije.` | `Ne mogu da učitam tutorijale.` |
| " | 104 | `Izaberite lekciju.` | `Izaberite tutorijal.` |
| " | 146 | `Zadaj lekciju — ${widget.studentName}` | `Zadaj tutorijal — ${widget.studentName}` |
| " | 179–180 | `Nemate nijednu sačuvanu lekciju. Napravite je u sesiji preko "Kreiraj lekciju", pa je odavde možete zadati.` | `Nemate nijedan sačuvan tutorijal. Napravite ga preko „Kreiraj tutorijal", pa ga odavde možete zadati.` |
| " | 192 | `Lekcija` (field label) | `Tutorijal` |
| " | 208 | `Lekcija` (fallback title) | `Tutorijal` |
| features/library/widgets/course_picker_dialog.dart | 77 | `U koju lekciju?` | `U koji tutorijal?` |
| " | 78 | `U koju lekciju? (${widget.count} pozicije)` | `U koji tutorijal? (${widget.count} pozicije)` |
| " | 122 | `Nema nijedne lekcije sa koracima. Napravite je preko „Kreiraj lekciju".` | `Nema nijednog tutorijala sa koracima. Napravite ga preko „Kreiraj tutorijal".` |
| features/position_scanner/screens/saved_positions_screen.dart | 562 | `Dodaj u lekciju` | `Dodaj u tutorijal` |
| features/reviews/screens/review_session_screen.dart | 398 | `Kada prođete kroz zadatu lekciju, pozicije iz nje počinju da se …` | `Kada prođete kroz zadati tutorijal, pozicije iz njega počinju da se …` |
| screens/chess_game_screen.dart | 1799 | `Obriši lekciju?` | `Obriši tutorijal?` |
| " | 1821 | `Lekcija obrisana.` | `Tutorijal obrisan.` |
| " | 1908 | `Lekcija sa varijacijama je uspešno sačuvana!` | `Tutorijal sa varijacijama je uspešno sačuvan!` |
| " | 1938 | `Lekcija sa varijacijama je učitana!` | `Tutorijal sa varijacijama je učitan!` |
| " | 1948 | `Učitana lekcija/FEN pozicija` | `Učitan tutorijal / FEN pozicija` |
| " | 2810 | `Lekcije i Pozicije` | `Tutorijali i pozicije` |
| " | 2855 | `Kreiraj lekciju (Više pozicija)` | `Kreiraj tutorijal (više pozicija)` |
| " | 2905 | `Pretraga lekcija` | `Pretraga tutorijala` |
| " | 3008 | `Nema sačuvanih lekcija u ovoj kategoriji.` | `Nema sačuvanih tutorijala u ovoj kategoriji.` |
| " | 3049 | `Sačuvana lekcija od trenera` | `Sačuvan tutorijal od trenera` |
| screens/shortcuts_screen.dart | 59 | `… analiza, soba, lekcija, …` | `… analiza, soba, tutorijal, …` |
| widgets/account_stats_card.dart | 115 | `Sačuvane lekcije / pozicije` | `Sačuvani tutorijali / pozicije` |
| widgets/create_course_dialog.dart | 153 | `Unesite naziv lekcije.` | `Unesite naziv tutorijala.` |
| " | 194 | `Lekcija je izmenjena (… koraka)!` | `Tutorijal je izmenjen (… koraka)!` |
| " | 195 | `Lekcija sa … koraka je sačuvana!` | `Tutorijal sa … koraka je sačuvan!` |
| " | 209 | `Izmeni lekciju` / `Kreiraj lekciju (Više koraka)` | `Izmeni tutorijal` / `Kreiraj tutorijal (više koraka)` |
| " | 229 | `Naziv lekcije / kursa` | `Naziv tutorijala` |
| " | 237 | `Opis kursa (opciono)` | `Opis tutorijala (opciono)` |
| " | 368 | `Sačuvaj lekciju` | `Sačuvaj tutorijal` |
| widgets/home/biblioteka_tab.dart | 46 | `Biblioteka Pozicija i Lekcija` | `Biblioteka pozicija i tutorijala` |
| " | 54 | `… pozicijama, PGN fajlovima i kursevima.` | `… pozicijama, PGN fajlovima i tutorijalima.` |
| widgets/home/dashboard_tab.dart | 275 | `Pozicije iz lekcija vraćaju se …` | `Pozicije iz tutorijala vraćaju se …` |
| widgets/home/home_dialogs.dart | 659 | `Neograničeno sačuvanih pozicija i lekcija (besplatno: do 20)` | `Neograničeno sačuvanih pozicija i tutorijala (besplatno: do 20)` |
| widgets/save_position_dialog.dart | 69 | `Sačuvaj trenutnu lekciju / poziciju` | `Sačuvaj trenutni tutorijal / poziciju` |
| " | 86 | `Naziv lekcije / pozicije` | `Naziv tutorijala / pozicije` |
| " | 204 | `Unesite naziv lekcije.` | `Unesite naziv tutorijala.` |
| screens/chess_game_screen.dart | 3057 | `Kurs od ${positionList.length} pozicija` | `Tutorijal od ${positionList.length} pozicija` |
| " | 3117 | `Učitan korak 1/… iz kursa: "…"` | `Učitan korak 1/… iz tutorijala: „…"` |
| widgets/game_screen/course_step_bar.dart | 61 | `${courseTitle ?? 'Kurs'} — korak …` | `${courseTitle ?? 'Tutorijal'} — korak …` |
| " | 94 | `Zatvori kurs` | `Zatvori tutorijal` |

**„Kurs" is in this table on purpose.** It is a third word for the same
artefact, and a glossary that leaves it standing has not finished the job: the
child would meet „lekcija", „kurs" and „tutorijal" for one thing.

## Table B — strings that become *Čas*, because they are the live session

| file | line | now | becomes |
|---|---|---|---|
| widgets/home/home_dialogs.dart | 25 | `Poziv na lekciju` | `Poziv na čas` |
| " | 27 | `Trener $trainerName vas poziva na lekciju. Da li želite da se pridružite?` | `Trener $trainerName vas poziva na čas. Da li želite da se pridružite?` |
| " | 460 | `Naslov sesije / lekcije` | `Naslov časa` |

Three rows, and they are the reason the whole table exists. Renaming these to
„tutorijal" would tell a child that a room opening right now is homework.

## Table C — not touched, and why

| what | where | why |
|---|---|---|
| `tags: const ['lekcija_kurs']` | widgets/create_course_dialog.dart:172,178 | **Stored data, not a sentence.** Every row already in the database carries this tag; changing the written value splits the label into two that never match. A migration is a separate, lead-owned job. |
| `AppLogger.log('… lekcije …')` | assignment_api_service.dart:128, assign_lesson_dialog.dart:81 | Log lines are read by us, not by a child. Out of scope, so the diff stays exactly the size of what a reader sees. |
| `PLAN-INTERAKTIVNA-LEKCIJA.md` in doc comments | 8 files | A file name. Renaming a reference to a document that still has that name makes the comment wrong. |
| API fields, route paths, `saved_lessons`, `position_list`, class and file names (`LessonViewerScreen`, `lesson_api_service.dart`, …) | everywhere | The word changes for the reader, not for the schema. An identifier rename is a diff nobody can review beside a string change, and it is not this batch. |
| `konekciju`, `sekcija`, `sesija` | several | They only match a careless `ekcij` search. Not this word. |

## Table D — backend strings (lead, not the worker)

Workers never touch `chess_backend/`. These are mine, and they land in phase 0
so the two halves cannot disagree in front of a child: the app would say
„tutorijal" while the server that answers it says „lekcija".

| file | line | now | becomes |
|---|---|---|---|
| routes/assignments.js | 337 | `Greška pri zadavanju lekcije.` | `Greška pri zadavanju tutorijala.` |
| routes/lessons.js | 113 | `Koraci su stigli bez svojih oznaka. Osvežite lekciju pa je sačuvajte ponovo.` | `Koraci su stigli bez svojih oznaka. Osvežite tutorijal pa ga sačuvajte ponovo.` |
| " | 138, 186 | `Lekcija nije pronađena ili nemate dozvolu za izmenu.` | `Tutorijal nije pronađen ili nemate dozvolu za izmenu.` |
| " | 158 | `Nepoznata lekcija.` | `Nepoznat tutorijal.` |
| " | 189 | `To je pojedinačna pozicija, ne lekcija sa koracima. Napravite lekciju u editoru.` | `To je pojedinačna pozicija, ne tutorijal sa koracima. Napravite tutorijal u editoru.` |
| " | 208 | `Lekcija nije pronađena ili nemate dozvolu za brisanje.` | `Tutorijal nije pronađen ili nemate dozvolu za brisanje.` |
| routes/reviews.js | 81 | `Nemate pristup toj lekciji.` | `Nemate pristup tom tutorijalu.` |
| " | 100 | `Taj korak više ne postoji u lekciji.` | `Taj korak više ne postoji u tutorijalu.` |
| services/assignmentService.js | 235 | `Lekcija nije pronađena ili nije vaša.` | `Tutorijal nije pronađen ili nije vaš.` |
| " | 238 | `Lekcija nema nijedan korak.` | `Tutorijal nema nijedan korak.` |
| services/lessonSteps.js | 304 | `Lekcija mora imati listu koraka.` | `Tutorijal mora imati listu koraka.` |
| " | 322 | `Korak …: oznaka „…" je već uzeta u ovoj lekciji.` | `Korak …: oznaka „…" je već uzeta u ovom tutorijalu.` |

Backend tests assert some of these strings. Changing a message and leaving its
test asserting the old one is a green suite that proves nothing — every changed
string is followed to its assertion.

## How this is graded

`docs/gates/tutorial_vocabulary_test.dart`, run against the worker's worktree.
It fails if:

1. any Dart **string literal** under `chess_app/lib/` still contains `lekcij` or
   `kurs` in any case, outside the allowances in Table C;
2. any replacement from Tables A–B is missing;
3. any file not named in a table changed;
4. the app's test count is below the baseline, or the analyzer list changed.

It is proved by mutation before it is trusted: put one row back, watch it go
red. A guard nobody has seen fail is not a guard.
