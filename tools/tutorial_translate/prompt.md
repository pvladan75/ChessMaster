# Translate a chess tutorial into {language}

You are translating the written text of a chess tutorial. Its readers are
children learning chess and the trainers who teach them. A voice will also read
most of it aloud, so it must sound natural when spoken.

Do not use any tools. Everything you need is in this message.

## What you receive and what you return

At the end of this message is a JSON list of items, each `{"id", "text"}`.
Return **every id exactly once, unchanged**, each with its text translated into
{language}. Do not add ids, drop ids, merge two items or split one.

What the ids mean:

- `title` - the tutorial's name. Short, like a chapter title.
- `description` - what the tutorial teaches. It is **Markdown**: keep every
  heading marker (`#`, `##`), every `**bold**`, every list marker (`-`, `1.`)
  and every line break exactly where they are. Translate only the words.
- `p<n>.title` - the name of part n of the tutorial.
- `p<n>.instruction` - a task addressed to the student („Find the move that
  wins"). Keep it an instruction, spoken to one student.
- `p<n>.choice<k>` - one answer the student can pick. Translate it as an answer
  and nothing more: never add or remove anything that would make it more or
  less obviously right.
- `p<n>.c<m>` - a sentence said about the position or the move just played on
  the board.

## Chess notation is not text

Copy every piece of chess notation **character for character**, exactly as it
appears in the source:

- moves: `e4`, `Nf3`, `Bxf7+`, `exd5`, `O-O`, `O-O-O`, `e8=Q#`, `Rxe8+`
- squares: `f7`, `d5`, `h8`
- move numbers: `12.` and `12...`
- the signs after a move: `+`, `#`, `!`, `?`, `!?`, `?!`

The piece letters in a move are **always** the English ones - K, Q, R, B, N -
whatever language you write in. Never write a move with another language's
letters (not `Lc4`, `Sf3`, `Dd1`, `Tc1`, `Ld5` - those are all wrong). The same
move must not gain or lose a sign, a space or a capital letter.

Only the notation stays as it is. The **words** for the pieces are translated
normally: „the bishop on c4" becomes the target language's word for *bishop*,
followed by `c4`.

A checker compares the notation of every item with its source, token by token.
An item whose notation differs is rejected and sent back.

## How to translate

- Keep the meaning exactly. Do not explain, shorten, soften or add anything -
  not a word of commentary, not a note about the translation.
- Short, clear sentences a child can follow. Where the source is simple, stay
  simple.
- Use the established chess terminology of {language}, the words a chess
  trainer in that language would use - not a word-for-word rendering of the
  English term.
- Address the student as one person, informally.
- Keep the names of players and of named positions (Philidor, Lolli, Vancura,
  Capablanca, Tarrasch, Carlsbad), spelled the way {language} normally spells
  them.
- Never write `{`, `}` or `[%` in a translation.
- Write ordinal numbers in the sentence as words - „the seventh rank", „on
  move twelve" - never as a digit with a full stop, which a voice reads as a
  number that ends the sentence. This is prose, not notation: a move number in
  front of a move (`12. Nf3`) is copied as it is.

## Only when {language} is Serbian

Ekavian, Latin script (unless the language asked for says Cyrillic), and the
student is addressed with *ti*. Foreign names are written the Serbian way:
Filidor, Loli, Vančura, Kapablanka, Taraš, Kohren, Rauzer.

The sides are written in lower case in the middle of a sentence, as Serbian
writes them: „beli je na potezu", „crni se brani" - not „Crni".

Ordinal numbers are words, declined as the sentence needs them: „sedmi red",
„na sedmom redu", „u dvanaestom potezu" - not „7. red", „u 12. potezu".

These are the words this app already uses, and a tutorial must agree with them:

| English | Serbian |
|---|---|
| tutorial, lesson (this document) | tutorijal - never „lekcija" or „čas", which mean other things in this app |
| White, Black (the sides) | beli, crni |
| endgame, draw | završnica, remi |
| king, queen, rook, bishop, knight, pawn | kralj, dama, top, lovac, skakač, pešak |
| check, checkmate, stalemate | šah, mat, pat |
| castling (short, long) | rokada (mala, velika) |
| rank, file, diagonal | red, linija, dijagonala |
| the exchange (rook for a minor piece) | kvalitet |
| opposition, zugzwang, tempo | opozicija, cugcvang, tempo |
| fortress | tvrđava |
| passed pawn, isolated pawn, hanging pawns | slobodan pešak, izolovani pešak, viseći pešaci |
| rook pawn | topovski pešak |
| key squares | ključna polja |
| pin, double attack (fork), discovered attack | vezivanje, dvostruki napad, otkriveni napad |
| sacrifice, Greek gift | žrtva, grčki poklon |
| minority attack, hedgehog, prophylaxis | napad manjinom, jež, profilaksa |
| promotion (a pawn promotes) | promocija (pešak se promoviše) |
