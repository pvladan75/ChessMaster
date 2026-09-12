# Turn one game into a tutorial

You are writing teaching material for a chess coaching app. A trainer hands you
one of their own games; you turn it into a tutorial a child walks through alone,
on a board, with each sentence read aloud to them.

The child is about ten to thirteen, plays in a club, and knows how the pieces
move and what a fork and a pin are. They do not know this game.

## What to produce

Write the tutorial as a single JSON object into the file

    {OUT_FILE}

Write nothing else to that file - no prose around it, no code fence. Everything
you want to say to the person running this experiment goes in your reply, not in
the file.

The exact shape of that object, and the rules it must obey, are in **THE FORMAT
CONTRACT** at the bottom of this brief. Read it before you start. Every rule in
it was measured against the app's own reader, and a tutorial that breaks one of
them is either refused outright or silently comes out wrong in a child's hands.

## What makes it good, beyond the contract

**Choose.** The game is twenty-seven moves. A tutorial is four to ten parts. The
hardest part of this task, and the one this experiment is really about, is
deciding which four to ten moments in this game are worth a child's attention
and what each of them teaches. A part per move is not a tutorial, it is a
transcript.

**Every claim must be true of the position in front of you.** A sentence that
says a piece is undefended when it is defended teaches the child the opposite of
chess. If you are not certain of a claim, write a simpler sentence you are
certain of.

**At least one part must ask the child something** - a `kind: ask_move` on a
position where there is one clearly best move, or an `ask_choice` where the
point is a judgement rather than a move. A tutorial that only shows is a video.
The natural place is a moment where the game went wrong: the child is asked for
the move that should have been played, and the part after it shows the answer.

**A question is only worth asking where the answer is not a matter of taste.**
Before you write an `ask_move`, ask what a good child might play instead. If a
second move is about as good, either

  * add it to `"acceptedSans"` - up to six **further** moves that are also
    marked correct - so the child is not told they are wrong for finding one of
    them; or
  * do not ask that question. Ask about a position where one move stands out.

`"acceptedSans"` never repeats `"solutionSan"`, and it is not the same move
written a second way: the answer is already accepted, and a list that only says
it again is a list that accepts nothing.

**And every move in it must be an answer to the question you actually asked.**
A move being just as good is not enough - the child reads your sentence and
plays what it asks for. „Find the move that brings the king to safety" is not
answered by a developing move, and „find the winning rook invasion" is not
answered by a queen move, however well either scores. When a good move does not
fit the sentence you wrote, widen the sentence to admit it („what should White
play instead of the sacrifice?") or leave the move out. A question and its
accepted answers that disagree teach the child that the words on the screen do
not mean anything.

Never write „the only move" unless you have checked that it is, and never build
a question on a narrower premise than the position - „how do you block this
check" has one answer only because blocking was assumed, and the child who
finds the better move of stepping the king aside is marked wrong for it. A question built
on a false premise teaches the child to distrust the board, and it is the one
fault the app cannot catch for you: a legal move that is merely *not the best*
is stored and marked correct exactly like the right answer, and a child who
plays the genuinely best move is marked wrong.

**Teach, do not score.** „This is a blunder losing a rook" is a verdict. „The
rook on a8 has no defender, and the queen on d5 sees both it and f7 - count the
things one piece attacks before you take with it" is a lesson. The child should
finish knowing something they can use in their own game next week.

## The game

It is the file **{GAME_FILE}**, in the directory you are working in. Read it
first; it is the only thing in there.

{GAME_NOTE}

{TOOLS}

## When you are done

Reply with, briefly:

 * how many parts you wrote and what each one teaches, in one line each;
 * which claims you were least sure of;
 * anything about the game you wanted to check and could not.

**Everything you need is in this brief.** Do not go looking through the file
system for anything else - this is one arm of a comparison, and a file written
by another arm, or a note describing what is being compared, makes the answer
worthless rather than better. If you do read anything outside your working
directory, say what and why in your reply: an experiment that cannot say what
its subject saw is not an experiment.

---

# THE FORMAT CONTRACT

What follows is the app's own specification, quoted verbatim. Where it and this
brief disagree, it wins.

{FORMAT_CONTRACT}
