5s
2s
Run cd chess_backend

> chess_backend@1.0.0 test
> node --test

TAP version 13
# Subtest: book notation becomes SAN chess.js accepts
ok 1 - book notation becomes SAN chess.js accepts
  ---
  duration_ms: 1.805067
  type: 'test'
  ...
# Subtest: a solution line yields the move, not the move plus the reply
ok 2 - a solution line yields the move, not the move plus the reply
  ---
  duration_ms: 1.50242
  type: 'test'
  ...
# Subtest: side to move is the first move token, not any ellipsis on the line
ok 3 - side to move is the first move token, not any ellipsis on the line
  ---
  duration_ms: 0.498012
  type: 'test'
  ...
# Subtest: the number runs into the move and is still recovered
ok 4 - the number runs into the move and is still recovered
  ---
  duration_ms: 0.252562
  type: 'test'
  ...
# Subtest: glyph rows become FEN ranks, and an unknown glyph is fatal
ok 5 - glyph rows become FEN ranks, and an unknown glyph is fatal
  ---
  duration_ms: 0.854999
  type: 'test'
  ...
# Subtest: a map is chosen by alphabet, and refused when nothing fits
ok 6 - a map is chosen by alphabet, and refused when nothing fits
  ---
  duration_ms: 0.361877
  type: 'test'
  ...
# Subtest: castling rights are restored from the solution, not assumed
ok 7 - castling rights are restored from the solution, not assumed
  ---
  duration_ms: 8.377691
  type: 'test'
  ...
# Subtest: the en passant square is restored from a capture onto an empty square
ok 8 - the en passant square is restored from a capture onto an empty square
  ---
  duration_ms: 1.634518
  type: 'test'
  ...
# Subtest: a position with no solution is kept but marked, never guessed
ok 9 - a position with no solution is kept but marked, never guessed
  ---
  duration_ms: 0.97826
  type: 'test'
  ...
# Subtest: accuracy is computed over all attempts
ok 10 - accuracy is computed over all attempts
  ---
  duration_ms: 1.719046
  type: 'test'
  ...
# Subtest: a student with no attempts reports null accuracy, not zero
ok 11 - a student with no attempts reports null accuracy, not zero
  ---
  duration_ms: 1.087434
  type: 'test'
  ...
# Subtest: a theme needs enough attempts before it counts as a weakness
ok 12 - a theme needs enough attempts before it counts as a weakness
  ---
  duration_ms: 0.522628
  type: 'test'
  ...
# Subtest: weakest and strongest are ordered from the same measured set
ok 13 - weakest and strongest are ordered from the same measured set
  ---
  duration_ms: 0.359893
  type: 'test'
  ...
# Subtest: a puzzle tagged with several motifs counts towards each
ok 14 - a puzzle tagged with several motifs counts towards each
  ---
  duration_ms: 0.377816
  type: 'test'
  ...
# Subtest: attempts without themes do not break the summary
ok 15 - attempts without themes do not break the summary
  ---
  duration_ms: 0.226964
  type: 'test'
  ...
# Subtest: assigned puzzles exclude ones the student already attempted
ok 16 - assigned puzzles exclude ones the student already attempted
  ---
  duration_ms: 0.59359
  type: 'test'
  ...
# Subtest: several chosen themes mean "any of", not "all of"
ok 17 - several chosen themes mean "any of", not "all of"
  ---
  duration_ms: 0.382977
  type: 'test'
  ...
# Subtest: non-trainable themes are dropped from the filter
ok 18 - non-trainable themes are dropped from the filter
  ---
  duration_ms: 0.360625
  type: 'test'
  ...
# Subtest: an empty first result falls back rather than assigning nothing
ok 19 - an empty first result falls back rather than assigning nothing
  ---
  duration_ms: 0.554938
  type: 'test'
  ...
# Subtest: the item count is clamped to a sane range
ok 20 - the item count is clamped to a sane range
  ---
  duration_ms: 0.270185
  type: 'test'
  ...
# Subtest: a missing rating range widens to the whole dataset
ok 21 - a missing rating range widens to the whole dataset
  ---
  duration_ms: 0.186178
  type: 'test'
  ...
# Subtest: intervals are ordered by start
ok 22 - intervals are ordered by start
  ---
  duration_ms: 2.273342
  type: 'test'
  ...
# Subtest: zero-length and inverted intervals are dropped
ok 23 - zero-length and inverted intervals are dropped
  ---
  duration_ms: 0.280174
  type: 'test'
  ...
# Subtest: overlapping intervals are merged
ok 24 - overlapping intervals are merged
  ---
  duration_ms: 0.27839
  type: 'test'
  ...
# Subtest: touching intervals are merged
ok 25 - touching intervals are merged
  ---
  duration_ms: 0.335938
  type: 'test'
  ...
# Subtest: garbage in the payload is ignored rather than trusted
ok 26 - garbage in the payload is ignored rather than trusted
  ---
  duration_ms: 0.219551
  type: 'test'
  ...
# Subtest: a negative start is clamped to the beginning of the file
ok 27 - a negative start is clamped to the beginning of the file
  ---
  duration_ms: 0.201778
  type: 'test'
  ...
# Subtest: the graph keeps the stretches between the pauses
ok 28 - the graph keeps the stretches between the pauses
  ---
  duration_ms: 0.4065
  type: 'test'
  ...
# Subtest: the tail after the last pause is left open-ended
ok 29 - the tail after the last pause is left open-ended
  ---
  duration_ms: 0.305682
  type: 'test'
  ...
# Subtest: a pause at the very start produces no empty leading stretch
ok 30 - a pause at the very start produces no empty leading stretch
  ---
  duration_ms: 0.453679
  type: 'test'
  ...
# Subtest: a single surviving stretch needs no concat
ok 31 - a single surviving stretch needs no concat
  ---
  duration_ms: 0.633856
  type: 'test'
  ...
# Subtest: milliseconds survive the conversion to seconds
ok 32 - milliseconds survive the conversion to seconds
  ---
  duration_ms: 0.224991
  type: 'test'
  ...
# Subtest: the author's own move is right
ok 33 - the author's own move is right
  ---
  duration_ms: 11.094783
  type: 'test'
  ...
# Subtest: decoration on the move does not decide anything
ok 34 - decoration on the move does not decide anything
  ---
  duration_ms: 2.198633
  type: 'test'
  ...
# Subtest: a different mate is still a mate, and the task was to mate
ok 35 - a different mate is still a mate, and the task was to mate
  ---
  duration_ms: 2.188023
  type: 'test'
  ...
# Subtest: an underpromotion that mates counts too
ok 36 - an underpromotion that mates counts too
  ---
  duration_ms: 5.33491
  type: 'test'
  ...
# Subtest: a move that does not mate is wrong even though it is legal
ok 37 - a move that does not mate is wrong even though it is legal
  ---
  duration_ms: 1.297737
  type: 'test'
  ...
# Subtest: an impossible move is refused without pretending it was played
ok 38 - an impossible move is refused without pretending it was played
  ---
  duration_ms: 0.647
  type: 'test'
  ...
# Subtest: when the task was not a mate, only the printed move counts
ok 39 - when the task was not a mate, only the printed move counts
  ---
  duration_ms: 0.80199
  type: 'test'
  ...
# Subtest: a position with no solution cannot be set as homework
ok 40 - a position with no solution cannot be set as homework
  ---
  duration_ms: 0.282628
  type: 'test'
  ...
# Subtest: a position still marked for review cannot be set either
ok 41 - a position still marked for review cannot be set either
  ---
  duration_ms: 1.016732
  type: 'test'
  ...
# Subtest: a verified position is assignable
ok 42 - a verified position is assignable
  ---
  duration_ms: 0.602788
  type: 'test'
  ...
# Subtest: a CA path means the certificate and hostname are verified
ok 43 - a CA path means the certificate and hostname are verified
  ---
  duration_ms: 4.822341
  type: 'test'
  ...
# Subtest: the CA path wins over DB_SSL rather than being overridden by it
ok 44 - the CA path wins over DB_SSL rather than being overridden by it
  ---
  duration_ms: 0.349744
  type: 'test'
  ...
# Subtest: an unreadable CA path stops the process instead of downgrading
ok 45 - an unreadable CA path stops the process instead of downgrading
  ---
  duration_ms: 4.772427
  type: 'test'
  ...
# Subtest: DB_SSL alone is the old unverified behaviour
ok 46 - DB_SSL alone is the old unverified behaviour
  ---
  duration_ms: 0.984081
  type: 'test'
  ...
# Subtest: neither set means no TLS, for a local PostgreSQL
ok 47 - neither set means no TLS, for a local PostgreSQL
  ---
  duration_ms: 0.20842
  type: 'test'
  ...
# Subtest: tier ordering places every paid tier above free
ok 48 - tier ordering places every paid tier above free
  ---
  duration_ms: 1.46473
  type: 'test'
  ...
# Subtest: highestTier keeps a manual grant when the subscription is weaker
ok 49 - highestTier keeps a manual grant when the subscription is weaker
  ---
  duration_ms: 0.305502
  type: 'test'
  ...
# Subtest: an active subscription with a future period end is entitling
ok 50 - an active subscription with a future period end is entitling
  ---
  duration_ms: 0.250539
  type: 'test'
  ...
# Subtest: a cancelled subscription keeps access until the paid period runs out
ok 51 - a cancelled subscription keeps access until the paid period runs out
  ---
  duration_ms: 0.235581
  type: 'test'
  ...
# Subtest: expired, on-hold and paused subscriptions grant nothing
ok 52 - expired, on-hold and paused subscriptions grant nothing
  ---
  duration_ms: 1.526606
  type: 'test'
  ...
# Subtest: an active subscription without an expiry is entitling, a cancelled one is not
ok 53 - an active subscription without an expiry is entitling, a cancelled one is not
  ---
  duration_ms: 0.171922
  type: 'test'
  ...
# Subtest: free accounts do not carry the paid entitlements
ok 54 - free accounts do not carry the paid entitlements
  ---
  duration_ms: 0.341799
  type: 'test'
  ...
# Subtest: an unknown tier falls back to free rather than granting everything
ok 55 - an unknown tier falls back to free rather than granting everything
  ---
  duration_ms: 0.472224
  type: 'test'
  ...
# Subtest: quota grows with tier and -1 marks unmetered
ok 56 - quota grows with tier and -1 marks unmetered
  ---
  duration_ms: 0.453168
  type: 'test'
  ...
# Subtest: usage periods bucket by UTC month
ok 57 - usage periods bucket by UTC month
  ---
  duration_ms: 0.747308
  type: 'test'
  ...
# Subtest: a Play purchase maps onto our subscription shape
ok 58 - a Play purchase maps onto our subscription shape
  ---
  duration_ms: 0.27285
  type: 'test'
  ...
# Subtest: an unmapped Play product yields no tier instead of a default one
ok 59 - an unmapped Play product yields no tier instead of a default one
  ---
  duration_ms: 0.15515
  type: 'test'
  ...
# Subtest: Play grace period is treated as still-paid, on hold is not
ok 60 - Play grace period is treated as still-paid, on hold is not
  ---
  duration_ms: 0.199954
  type: 'test'
  ...
# Subtest: RTDN envelopes decode, and malformed ones return null instead of throwing
ok 61 - RTDN envelopes decode, and malformed ones return null instead of throwing
  ---
  duration_ms: 0.805256
  type: 'test'
  ...
# Subtest: the marker written by Google sign-in reads as passwordless
ok 62 - the marker written by Google sign-in reads as passwordless
  ---
  duration_ms: 1.511047
  type: 'test'
  ...
# Subtest: a real bcrypt hash never reads as passwordless
ok 63 - a real bcrypt hash never reads as passwordless
  ---
  duration_ms: 0.194334
  type: 'test'
  ...
# Subtest: a missing or non-string hash is not mistaken for a Google account
ok 64 - a missing or non-string hash is not mistaken for a Google account
  ---
  duration_ms: 0.206817
  type: 'test'
  ...
# Subtest: login checks for a passwordless account before comparing a password
ok 65 - login checks for a passwordless account before comparing a password
  ---
  duration_ms: 0.594542
  type: 'test'
  ...
# Subtest: the marker is defined once and reused by the Google route
ok 66 - the marker is defined once and reused by the Google route
  ---
  duration_ms: 0.483895
  type: 'test'
  ...
# Subtest: the first move is the opponent's mistake, not part of the solution
ok 67 - the first move is the opponent's mistake, not part of the solution
  ---
  duration_ms: 2.386083
  type: 'test'
  ...
# Subtest: a degenerate move line yields no solution rather than a wrong one
ok 68 - a degenerate move line yields no solution rather than a wrong one
  ---
  duration_ms: 0.302316
  type: 'test'
  ...
# Subtest: only skill themes are kept for rating
ok 69 - only skill themes are kept for rating
  ---
  duration_ms: 0.275254
  type: 'test'
  ...
# Subtest: the weakest sufficiently-measured theme is chosen
ok 70 - the weakest sufficiently-measured theme is chosen
  ---
  duration_ms: 0.385882
  type: 'test'
  ...
# Subtest: a theme with too few attempts is not treated as a weakness
ok 71 - a theme with too few attempts is not treated as a weakness
  ---
  duration_ms: 0.225241
  type: 'test'
  ...
# Subtest: a user with no history explores instead of returning nothing
ok 72 - a user with no history explores instead of returning nothing
  ---
  duration_ms: 0.26763
  type: 'test'
  ...
# Subtest: exploration serves an untried theme, not the known weakest
ok 73 - exploration serves an untried theme, not the known weakest
  ---
  duration_ms: 0.253064
  type: 'test'
  ...
# Subtest: once every theme is measured, exploration cannot break the pick
ok 74 - once every theme is measured, exploration cannot break the pick
  ---
  duration_ms: 0.204443
  type: 'test'
  ...
# Subtest: the rating band sits slightly below the user and widens on retry
ok 75 - the rating band sits slightly below the user and widens on retry
  ---
  duration_ms: 0.402092
  type: 'test'
  ...
# Subtest: a database row becomes a client payload with the solution split out
ok 76 - a database row becomes a client payload with the solution split out
  ---
  duration_ms: 0.499935
  type: 'test'
  ...
# Subtest: a real CSV line parses into the columns the importer writes
ok 77 - a real CSV line parses into the columns the importer writes
  ---
  duration_ms: 0.359512
  type: 'test'
  ...
# Subtest: an opening-tagged row keeps its tags as an array
ok 78 - an opening-tagged row keeps its tags as an array
  ---
  duration_ms: 0.149449
  type: 'test'
  ...
# Subtest: malformed rows are rejected instead of imported as garbage
ok 79 - malformed rows are rejected instead of imported as garbage
  ---
  duration_ms: 0.114384
  type: 'test'
  ...
# Subtest: an edge only counts once it has been accepted
ok 80 - an edge only counts once it has been accepted
  ---
  duration_ms: 4.79504
  type: 'test'
  ...
# Subtest: a pending edge grants nothing
ok 81 - a pending edge grants nothing
  ---
  duration_ms: 0.329847
  type: 'test'
  ...
# Subtest: a request starts pending and remembers who started it
ok 82 - a request starts pending and remembers who started it
  ---
  duration_ms: 0.382556
  type: 'test'
  ...
# Subtest: a student asking a trainer lands in the other column
ok 83 - a student asking a trainer lands in the other column
  ---
  duration_ms: 0.274414
  type: 'test'
  ...
# Subtest: nobody may become their own trainer
ok 84 - nobody may become their own trainer
  ---
  duration_ms: 0.21387
  type: 'test'
  ...
# Subtest: an existing accepted relationship is not requested again
ok 85 - an existing accepted relationship is not requested again
  ---
  duration_ms: 0.323054
  type: 'test'
  ...
# Subtest: the existing-relationship check looks both ways
ok 86 - the existing-relationship check looks both ways
  ---
  duration_ms: 0.279292
  type: 'test'
  ...
# Subtest: you cannot become the trainer of your own trainer
ok 87 - you cannot become the trainer of your own trainer
  ---
  duration_ms: 0.324377
  type: 'test'
  ...
# Subtest: asking to be taught by your own student is refused the same way
ok 88 - asking to be taught by your own student is refused the same way
  ---
  duration_ms: 0.551461
  type: 'test'
  ...
# Subtest: an unanswered request in the other direction blocks this one too
ok 89 - an unanswered request in the other direction blocks this one too
  ---
  duration_ms: 0.662569
  type: 'test'
  ...
# Subtest: the reverse row does not block once it is gone
ok 90 - the reverse row does not block once it is gone
  ---
  duration_ms: 0.255598
  type: 'test'
  ...
# Subtest: repeating a request is not an error, the invitation still stands
ok 91 - repeating a request is not an error, the invitation still stands
  ---
  duration_ms: 0.209902
  type: 'test'
  ...
# Subtest: accepting requires being the side that did not ask
ok 92 - accepting requires being the side that did not ask
  ---
  duration_ms: 0.466593
  type: 'test'
  ...
# Subtest: friendship is created only after a request is actually accepted
ok 93 - friendship is created only after a request is actually accepted
  ---
  duration_ms: 0.220602
  type: 'test'
  ...
# Subtest: answering a request stops its notification from nagging
ok 94 - answering a request stops its notification from nagging
  ---
  duration_ms: 0.358991
  type: 'test'
  ...
# Subtest: declining names the sender so they can be told
ok 95 - declining names the sender so they can be told
  ---
  duration_ms: 0.236292
  type: 'test'
  ...
# Subtest: the sender is found from whichever column they sit in
ok 96 - the sender is found from whichever column they sit in
  ---
  duration_ms: 0.246932
  type: 'test'
  ...
# Subtest: the decline notice says no without saying why
ok 97 - the decline notice says no without saying why
  ---
  duration_ms: 0.295192
  type: 'test'
  ...
# Subtest: a failed decline notice does not undo the decline
ok 98 - a failed decline notice does not undo the decline
  ---
  duration_ms: 1.239227
  type: 'test'
  ...
# Subtest: a declined request closes its notification too
ok 99 - a declined request closes its notification too
  ---
  duration_ms: 1.341389
  type: 'test'
  ...
# Subtest: a refused answer leaves the notification alone
ok 100 - a refused answer leaves the notification alone
  ---
  duration_ms: 0.19282
  type: 'test'
  ...
# Subtest: a refused acceptance creates no friendship
ok 101 - a refused acceptance creates no friendship
  ---
  duration_ms: 0.192349
  type: 'test'
  ...
# Subtest: declining deletes the request under the same guard
ok 102 - declining deletes the request under the same guard
  ---
  duration_ms: 0.224531
  type: 'test'
  ...
# Subtest: reading through the edge also requires acceptance
ok 103 - reading through the edge also requires acceptance
  ---
  duration_ms: 0.340226
  type: 'test'
  ...
# Subtest: the fragment refuses anything that is not a placeholder
ok 104 - the fragment refuses anything that is not a placeholder
  ---
  duration_ms: 0.578181
  type: 'test'
  ...
# Subtest: no call site reads the edge without filtering on status
ok 105 - no call site reads the edge without filtering on status
  ---
  duration_ms: 2.417413
  type: 'test'
  ...
# Subtest: pending list excludes what I asked for myself
ok 106 - pending list excludes what I asked for myself
  ---
  duration_ms: 0.242344
  type: 'test'
  ...
# [2026-08-19 21:59:10] ERROR: Could not create decline notification:
# Subtest: escapes every character that could break out into markup
ok 107 - escapes every character that could break out into markup
  ---
  duration_ms: 1.405509
  type: 'test'
  ...
# Subtest: a trainer note cannot inject script into the parent's page
ok 108 - a trainer note cannot inject script into the parent's page
  ---
  duration_ms: 0.883152
  type: 'test'
  ...
# Subtest: a student name with markup characters is escaped too
ok 109 - a student name with markup characters is escaped too
  ---
  duration_ms: 0.28919
  type: 'test'
  ...
# Subtest: motif codes are shown in Serbian, not as Lichess tags
ok 110 - motif codes are shown in Serbian, not as Lichess tags
  ---
  duration_ms: 0.247673
  type: 'test'
  ...
# Subtest: an unknown motif falls back to its raw tag rather than disappearing
ok 111 - an unknown motif falls back to its raw tag rather than disappearing
  ---
  duration_ms: 0.328324
  type: 'test'
  ...
# Subtest: every theme line states how many attempts it is based on
ok 112 - every theme line states how many attempts it is based on
  ---
  duration_ms: 0.24071
  type: 'test'
  ...
# Subtest: a single attempt is counted in the singular
ok 113 - a single attempt is counted in the singular
  ---
  duration_ms: 0.323445
  type: 'test'
  ...
# Subtest: a period with no activity says so instead of showing zeroes
ok 114 - a period with no activity says so instead of showing zeroes
  ---
  duration_ms: 0.229971
  type: 'test'
  ...
# Subtest: an unknown accuracy renders as a dash, never as 0%
ok 115 - an unknown accuracy renders as a dash, never as 0%
  ---
  duration_ms: 0.510945
  type: 'test'
  ...
# Subtest: rating movement is signed, and absent when there is nothing to compare
ok 116 - rating movement is signed, and absent when there is nothing to compare
  ---
  duration_ms: 0.760362
  type: 'test'
  ...
# Subtest: empty theme lists explain themselves rather than rendering blank
ok 117 - empty theme lists explain themselves rather than rendering blank
  ---
  duration_ms: 0.227456
  type: 'test'
  ...
# Subtest: the note section is omitted entirely when the trainer wrote nothing
ok 118 - the note section is omitted entirely when the trainer wrote nothing
  ---
  duration_ms: 0.204132
  type: 'test'
  ...
# Subtest: the page asks not to be indexed
ok 119 - the page asks not to be indexed
  ---
  duration_ms: 0.171411
  type: 'test'
  ...
# Subtest: dates render in Serbian day-first order
ok 120 - dates render in Serbian day-first order
  ---
  duration_ms: 0.136285
  type: 'test'
  ...
# Subtest: deletes exports older than the cutoff, keeps recent ones
ok 121 - deletes exports older than the cutoff, keeps recent ones
  ---
  duration_ms: 2.562293
  type: 'test'
  ...
# Subtest: a missing directory is a no-op, not an error
ok 122 - a missing directory is a no-op, not an error
  ---
  duration_ms: 0.752939
  type: 'test'
  ...
# Subtest: nothing older than the cutoff means nothing deleted
ok 123 - nothing older than the cutoff means nothing deleted
  ---
  duration_ms: 0.319568
  type: 'test'
  ...
# Subtest: clears video_url for recordings pointing at a deleted export
ok 124 - clears video_url for recordings pointing at a deleted export
  ---
  duration_ms: 0.626512
  type: 'test'
  ...
# [2026-08-19 21:59:10] INFO: [RETENTION] Deleted 1 export(s) older than 14d, freed 0.0MB
# [2026-08-19 21:59:10] INFO: [RETENTION] Deleted 1 export(s) older than 14d, freed 0.0MB
# Subtest: a valid position becomes a row, with the side taken from the FEN
ok 125 - a valid position becomes a row, with the side taken from the FEN
  ---
  duration_ms: 8.144475
  type: 'test'
  ...
# Subtest: the side to move is never taken from the client, only from the FEN
ok 126 - the side to move is never taken from the client, only from the FEN
  ---
  duration_ms: 0.238827
  type: 'test'
  ...
# Subtest: a FEN that is not a position is rejected and named
ok 127 - a FEN that is not a position is rejected and named
  ---
  duration_ms: 0.9676
  type: 'test'
  ...
# Subtest: a solution that will not play is dropped, and the position is flagged
ok 128 - a solution that will not play is dropped, and the position is flagged
  ---
  duration_ms: 0.404036
  type: 'test'
  ...
# Subtest: a position with no solution at all is not flagged
ok 129 - a position with no solution at all is not flagged
  ---
  duration_ms: 0.341559
  type: 'test'
  ...
# Subtest: the trainer's own doubt survives a solution that verifies
ok 130 - the trainer's own doubt survives a solution that verifies
  ---
  duration_ms: 2.278082
  type: 'test'
  ...
# Subtest: themes are trimmed, capped and stripped of anything that is not a string
ok 131 - themes are trimmed, capped and stripped of anything that is not a string
  ---
  duration_ms: 0.536233
  type: 'test'
  ...
# Subtest: castling rights the scanner restored survive intake
ok 132 - castling rights the scanner restored survive intake
  ---
  duration_ms: 1.904322
  type: 'test'
  ...
# Subtest: a re-scan fills a gap without touching what is already there
ok 133 - a re-scan fills a gap without touching what is already there
  ---
  duration_ms: 4.017325
  type: 'test'
  ...
# Subtest: a re-scan never overwrites a value that is already set
ok 134 - a re-scan never overwrites a value that is already set
  ---
  duration_ms: 4.807573
  type: 'test'
  ...
# Subtest: a solution that will not play in the stored position is a conflict, not a fill
ok 135 - a solution that will not play in the stored position is a conflict, not a fill
  ---
  duration_ms: 9.394492
  type: 'test'
  ...
# Subtest: nothing to add means nothing changes
ok 136 - nothing to add means nothing changes
  ---
  duration_ms: 0.35329
  type: 'test'
  ...
# Subtest: settling the side rewrites the FEN and drops the en passant square
ok 137 - settling the side rewrites the FEN and drops the en passant square
  ---
  duration_ms: 0.276366
  type: 'test'
  ...
# Subtest: settling the side keeps castling rights
ok 138 - settling the side keeps castling rights
  ---
  duration_ms: 0.263673
  type: 'test'
  ...
# Subtest: an answer that is not a side is refused
ok 139 - an answer that is not a side is refused
  ---
  duration_ms: 0.716691
  type: 'test'
  ...
# Subtest: a position with no solution is not in doubt, only unfinished
ok 140 - a position with no solution is not in doubt, only unfinished
  ---
  duration_ms: 3.577782
  type: 'test'
  ...
# Subtest: settling the side can break a stored solution, and that must stay visible
ok 141 - settling the side can break a stored solution, and that must stay visible
  ---
  duration_ms: 1.651168
  type: 'test'
  ...
# Subtest: a conflict names the likely cause instead of just refusing
ok 142 - a conflict names the likely cause instead of just refusing
  ---
  duration_ms: 5.476875
  type: 'test'
  ...
# Subtest: a conflict with no such explanation says only what it knows
ok 143 - a conflict with no such explanation says only what it knows
  ---
  duration_ms: 0.42235
  type: 'test'
  ...
# Subtest: a verified mate in one states its own task
ok 144 - a verified mate in one states its own task
  ---
  duration_ms: 3.77287
  type: 'test'
  ...
# Subtest: a black mate in one says so in black's name
ok 145 - a black mate in one says so in black's name
  ---
  duration_ms: 1.276157
  type: 'test'
  ...
# Subtest: anything short of a mate invents no task at all
ok 146 - anything short of a mate invents no task at all
  ---
  duration_ms: 0.794556
  type: 'test'
  ...
# Subtest: the trainer's own words are kept, never replaced by a derived task
ok 147 - the trainer's own words are kept, never replaced by a derived task
  ---
  duration_ms: 1.255438
  type: 'test'
  ...
# Subtest: a position with no instruction gets the derived one
ok 148 - a position with no instruction gets the derived one
  ---
  duration_ms: 4.426707
  type: 'test'
  ...
# Subtest: a re-scan fills a missing task but never overwrites one
ok 149 - a re-scan fills a missing task but never overwrites one
  ---
  duration_ms: 10.027758
  type: 'test'
  ...
# [2026-08-19 21:59:10] ERROR: FATAL: JWT_SECRET is not configured. Generate one with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
# Subtest: test/scanSweep.test.js
not ok 13 - test/scanSweep.test.js
  ---
  duration_ms: 381.1278
  type: 'test'
  location: '/home/runner/work/ChessMaster/ChessMaster/chess_backend/test/scanSweep.test.js:1:1'
  failureType: 'testCodeFailure'
  exitCode: 1
  signal: ~
  error: 'test failed'
  code: 'ERR_TEST_FAILURE'
  ...
# Subtest: the first two intervals are fixed at 1 and 6 days
ok 151 - the first two intervals are fixed at 1 and 6 days
  ---
  duration_ms: 1.547615
  type: 'test'
  ...
# Subtest: from the third review the interval compounds by the ease factor
ok 152 - from the third review the interval compounds by the ease factor
  ---
  duration_ms: 0.258854
  type: 'test'
  ...
# Subtest: the due date matches the interval it reports
ok 153 - the due date matches the interval it reports
  ---
  duration_ms: 0.241222
  type: 'test'
  ...
# Subtest: a failed item comes back in the same session, not tomorrow
ok 154 - a failed item comes back in the same session, not tomorrow
  ---
  duration_ms: 0.282679
  type: 'test'
  ...
# Subtest: a lapse keeps the ease factor rather than resetting it
ok 155 - a lapse keeps the ease factor rather than resetting it
  ---
  duration_ms: 0.285975
  type: 'test'
  ...
# Subtest: lapses accumulate across failures
ok 156 - lapses accumulate across failures
  ---
  duration_ms: 0.210814
  type: 'test'
  ...
# Subtest: the ease factor never falls below the SM-2 floor
ok 157 - the ease factor never falls below the SM-2 floor
  ---
  duration_ms: 0.310812
  type: 'test'
  ...
# Subtest: "easy" raises the ease factor and "hard" lowers it
ok 158 - "easy" raises the ease factor and "hard" lowers it
  ---
  duration_ms: 0.197109
  type: 'test'
  ...
# Subtest: grade 3 passes while grade 2 fails, at the SM-2 boundary
ok 159 - grade 3 passes while grade 2 fails, at the SM-2 boundary
  ---
  duration_ms: 0.429343
  type: 'test'
  ...
# Subtest: an interval never rounds down to zero on a pass
ok 160 - an interval never rounds down to zero on a pass
  ---
  duration_ms: 0.503922
  type: 'test'
  ...
# Subtest: missing state is treated as a brand new item
ok 161 - missing state is treated as a brand new item
  ---
  duration_ms: 0.166061
  type: 'test'
  ...
# Subtest: only whole grades 0 to 5 are accepted
ok 162 - only whole grades 0 to 5 are accepted
  ---
  duration_ms: 0.162714
  type: 'test'
  ...
# Subtest: intervals are described in natural Serbian
ok 163 - intervals are described in natural Serbian
  ---
  duration_ms: 0.180337
  type: 'test'
  ...
# Subtest: a long-running schedule grows but stays finite
ok 164 - a long-running schedule grows but stays finite
  ---
  duration_ms: 0.213099
  type: 'test'
  ...
# Subtest: a theme is never both a strength and a weakness
ok 165 - a theme is never both a strength and a weakness
  ---
  duration_ms: 2.812832
  type: 'test'
  ...
# Subtest: a middling theme is neither, and says so by absence
ok 166 - a middling theme is neither, and says so by absence
  ---
  duration_ms: 0.319618
  type: 'test'
  ...
# Subtest: a single strong theme still counts as a strength
ok 167 - a single strong theme still counts as a strength
  ---
  duration_ms: 0.289843
  type: 'test'
  ...
# Subtest: a single weak theme still counts as a weakness
ok 168 - a single weak theme still counts as a weakness
  ---
  duration_ms: 0.368329
  type: 'test'
  ...
# Subtest: too few attempts means unmeasured, not weak
ok 169 - too few attempts means unmeasured, not weak
  ---
  duration_ms: 0.312083
  type: 'test'
  ...
# Subtest: strengths come best first, weaknesses worst first
ok 170 - strengths come best first, weaknesses worst first
  ---
  duration_ms: 0.48631
  type: 'test'
  ...
# Subtest: no attempts at all produces no claims
ok 171 - no attempts at all produces no claims
  ---
  duration_ms: 0.223498
  type: 'test'
  ...
# Subtest: the report groups a user's metrics and converts voice seconds to minutes
ok 172 - the report groups a user's metrics and converts voice seconds to minutes
  ---
  duration_ms: 1.650578
  type: 'test'
  ...
# Subtest: users are ranked by estimated cost, most expensive first
ok 173 - users are ranked by estimated cost, most expensive first
  ---
  duration_ms: 0.696202
  type: 'test'
  ...
# Subtest: an empty month reports zero rather than failing
ok 174 - an empty month reports zero rather than failing
  ---
  duration_ms: 0.928758
  type: 'test'
  ...
# Subtest: recordUsage writes an additive increment for the current period
ok 175 - recordUsage writes an additive increment for the current period
  ---
  duration_ms: 0.718534
  type: 'test'
  ...
# Subtest: recordUsage ignores meaningless amounts instead of writing noise
ok 176 - recordUsage ignores meaningless amounts instead of writing noise
  ---
  duration_ms: 0.254946
  type: 'test'
  ...
# Subtest: a failing database never propagates out of recordUsage
ok 177 - a failing database never propagates out of recordUsage
  ---
  duration_ms: 1.381243
  type: 'test'
  ...
# [2026-08-19 21:59:10] ERROR: Failed to record usage: connection reset
#     userId: 1
#     metric: "mp4_renders"
#     amount: 1
# Subtest: frameLength measures a real compressed frame exactly
ok 178 - frameLength measures a real compressed frame exactly
  ---
  duration_ms: 39.40221
  type: 'test'
  ...
# Subtest: frameLength recognises and measures a skippable frame
ok 179 - frameLength recognises and measures a skippable frame
  ---
  duration_ms: 0.278511
  type: 'test'
  ...
# Subtest: frameLength asks for more data instead of guessing at a truncated frame
ok 180 - frameLength asks for more data instead of guessing at a truncated frame
  ---
  duration_ms: 7.079723
  type: 'test'
  ...
# Subtest: frameLength rejects bytes that are not a frame at all
ok 181 - frameLength rejects bytes that are not a frame at all
  ---
  duration_ms: 0.669232
  type: 'test'
  ...
# Subtest: every frame is decompressed, not just the first
ok 182 - every frame is decompressed, not just the first
  ---
  duration_ms: 18.166581
  type: 'test'
  ...
# Subtest: a record split across a frame boundary is rejoined
ok 183 - a record split across a frame boundary is rejoined
  ---
  duration_ms: 2.381665
  type: 'test'
  ...
# Subtest: a final line without a trailing newline is still emitted
ok 184 - a final line without a trailing newline is still emitted
  ---
  duration_ms: 1.251261
  type: 'test'
  ...
# Subtest: a truncated file fails loudly rather than returning partial data
ok 185 - a truncated file fails loudly rather than returning partial data
  ---
  duration_ms: 2.687106
  type: 'test'
  ...
1..185
# tests 185
# suites 0
# pass 184
# fail 1
# cancelled 0
# skipped 0
# todo 0
# duration_ms 1175.520776
Error: Process completed with exit code 1.