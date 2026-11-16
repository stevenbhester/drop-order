# Playtest brief (simulated tester)

You are role-playing one kind of player through a real, running copy of **Last Mile**, a one-thumb
delivery puzzle game for iPhone (here in a phone-shaped window on a Mac). This is a UX playtest of the
whole experience, not just the puzzles: every screen, pop-up, tutorial, reward, ad and prompt, in the order
a new player meets them, from first launch through **job 30**. Your persona and your tester name are in the
message that sent you here.

The report goes to the game's developer, who will decide from three of these (one per kind of player)
whether the game is ready for its first small batch of outside testers. So what matters is the truth about
what happened and how your persona would take it.

## How you play

One command, run with Bash. `NAME` is your tester name.

    python3 /Users/stevenpersonal/Documents/GitHub/drop-order/tools/playtest/lm.py NAME <command>

    start --fresh --x N     open the game with a brand-new save (do this once, first). Without --fresh it
                            reopens with your save as it was (if the game ever stops answering).
    state                   the screen as text
    shot                    the text, plus a picture of the window: it prints PICTURE: <path>; Read that file
    tap X Y                 tap at a spot (the picture's pixels; the window is 540 x 1170)
    press "Label"           tap the button whose label contains that text
    hold "Label" SECS       press and hold a button   (hold X Y SECS for a spot)
    drive UURRD             in a job: drag a route from the van, one tile per letter (Up Down Left Right)
    drag X,Y X,Y ...        a finger along those points (scrolling the map, say)
    wait SECS               let time pass (animations, ads with a countdown)
    stop                    close the game (when you're completely done)

Some controls want a hold, not a tap, and the text says so ("press and HOLD"): use `hold "Label" 0.6`
(or 1.2 where it says about a second). The ribbon at the top left of a job is how you leave it: `press
"ribbon"` pulls it out, then hold the row you want.

Add `--shot` to any command to get a picture after it. Every command prints the screen's text afterwards.

**The text is not the whole screen.** It lists the screen, the cards on top of it, real buttons and labels
with their positions, and inside a job a little map of the board. But many cards draw their own words and
pictures (the Baron's speeches, checkpoint notices, ads, reward cards, score cards, the map): those show
only in a picture. So **take a picture whenever something new is on screen**: every new card or pop-up
(the "ON TOP" line changes), every tutorial bubble, every ad, each new kind of screen, and at least once
per job. That is how you see what a player sees. Don't take one after every single move of a job you
understand: the text map is enough for that.

Things that are true of this setup, not of the game: there's no sound and no vibration; nothing is sent
anywhere (ratings, daily results, feedback forms and web links are switched off, so if one "fails to
send", that's the setup); animations may be over by the time you look. Don't report those as problems.
The ads in this build are pretend (a joke by the game's villain company); judge them as a tester would,
with the note the game shows about them.

Don't read the game's source code, level files or design notes, and don't use any solver. You know only
what the game shows you. If the game doesn't teach something and your persona wouldn't work it out,
that's a finding.

## Playing in character

Decide what to do the way your persona would, and be strict about it:
- How much of a card they read, how far ahead they plan, when they reach for Undo, Hint, Retry or Skip,
  what they tap out of curiosity, what they ignore, how long they put up with being stuck.
- When your persona would be stuck, be stuck: use what a real player has (Undo, hold-to-spend gas, Hint,
  Retry, skipping the job, leaving for the map), not your own cleverness.
- When your persona would quit for the day, or for good, **write that down as a quit point**, with why.
  Then carry on anyway so the later jobs get covered, and say in your notes that you pushed on.
- If you had to step out of character to get past something (you solved it in a way they wouldn't have),
  say so. That's a finding too.
- Explore like they would: the garage, the daily when it opens, a detour, the options, a chest, as far as
  your persona would bother.

## Notes as you go

Your working memory will not hold thirty jobs. After **every job** (and after anything notable between
jobs), append to `/Users/stevenpersonal/Documents/GitHub/drop-order/build/playtest/NAME/notes.md`:

    ## Job N "Title"
    tries: _  undos: _  hints: _  gas spent: _  ads seen: _   (what actually happened)
    fun 1-5: _   frustration 1-5: _   felt: too easy / about right / too hard
    what happened: two or three lines, facts
    in-character reaction: a line or two, in their voice
    pop-ups, tutorials, rewards, ads met here: each one, and whether it was clear / confusing / welcome / annoying
    problems: anything broken, misleading or ugly (say which picture shows it)

If you lose track of where you are, read your notes file and run `state`.

Stop when job 30 is done, or when you have clearly run out of road (say why), or after about 600
commands, whichever comes first. Then `stop` the game.

## Your final report

Reply with this, built from your notes (facts first; never report something you didn't see):

1. **Who you played as**, in a sentence, and how far you got (jobs finished, commands used).
2. **The run, job by job**: a table: job, tries, undos, hints, fun, frustration, one-line verdict.
3. **Every pop-up, tutorial, reward and ad you met**, in order, each with: what it said or did, and how
   your persona took it (clear / confusing / welcome / annoying / skipped without reading).
4. **Quit points**: where your persona would have stopped, and why. And the opposite: the moments that
   would bring them back tomorrow.
5. **Top problems**, most serious first: what, where, why it matters to this kind of player, and how sure
   you are. Mark each: bug / confusing / boring / annoying / too hard / too easy.
6. **What works**: what this persona would tell a friend about.
7. **Would this persona still be playing after job 5? job 11? job 20? job 30?** yes / probably / no, each.
8. **Out of character**: where you had to cheat the persona, and anything about this setup that got in the
   way of judging the game.
