# Last Mile: prompts for the background music

For Suno (or Udio, or any text-to-music tool). One song per kind of puzzle, three variants of each.
Written 2026-11-18. The game side (beat-matched mixing, never the same variant twice running) is Claude's job
once the files exist: see "Bringing them back" at the bottom.

## How to use

1. Turn **Instrumental** on.
2. Paste the **shared style** below, then the song's own line after it, into the style box.
3. Generate until one fits. That's variant A.
4. For B and C, use the tool's remix / cover / "reuse prompt" on variant A and add the variant line. If it has
   no such feature, rerun the same prompt with the variant line on the end.
5. Aim for 1:30 to 2:30 each. Skip any take with a long intro, a big ending, or vocals.

The tempo and key are the same in every prompt on purpose: that is what lets the game blend one song into the
next on the beat without the two clashing. These tools treat BPM and key as a suggestion, so don't fight it:
anything from about 98 to 110 BPM is fine, and the game can nudge the speed to match.

## Shared style (start every prompt with this)

```
Instrumental, no vocals. Subtle background music for a cozy puzzle game. 104 BPM, 4/4, F major. Lo-fi neo-soul meets organic electronica: plucked nylon guitar, electric piano, round warm bass, soft brushed drums, finger snaps. Warm, soft, understated mix, nothing harsh or bright, no big drops, no risers, no long intro or outro. Steady from the first bar so it loops.
```

Short form, if the style box only takes about 200 characters (then put the song's line in the description or
lyrics box as a note):

```
instrumental, cozy puzzle game background, 104 BPM, F major, lo-fi neo-soul, organic electronica, plucked guitar, electric piano, warm bass, soft drums, subtle, loopable
```

## The songs

Each line goes after the shared style. "Why" is what the puzzle is, so you can judge a take.

### On the main road (by the job's flavour)

| Song | Jobs | Why | Add to the style |
|---|---|---|---|
| **intro** | 14 | Teaches something new, gently. | `Curious and friendly. A simple kalimba melody of a few notes, repeated and gently added to each time, like learning something. Lots of space.` |
| **practice** | 3 | Nothing new: a rep of what you know. | `Easygoing and sure of itself. A relaxed stroll: walking bass, light swing, a whistled-sounding flute lead.` |
| **breather** | 6 | Several ways through. A rest. | `Airy and open. Slow pads and nylon guitar, half-time feel, long reverb, almost no drums. A deep breath.` |
| **twodoor** | 13 | A house you can reach from two roads; which door is the puzzle. | `Call and response: a guitar on the left and an electric piano on the right trade the same short phrase, each answering it a different way.` |
| **twin** | 2 | Two different answers. | `A duet: two melodies in close harmony, a third apart, mirroring each other. Clarinet and vibraphone.` |
| **decoy** | 10 | The obvious route is the wrong one. | `Sneaky and playful. Tiptoeing pizzicato strings and a muted trumpet, staccato, spy-comedy. Phrases that set off one way and swerve at the end.` |
| **longcon** | 9 | An early choice pays off (or bites) much later. | `A slow-burn heist groove. One patient bass figure that never changes while layers arrive one at a time. Something building under the surface.` |
| **melter** | 14 | Looks impossible until it clicks. | `Dreamy, woozy, hypnotic. Detuned electric piano with tape wobble, an odd-length arpeggio that seems to slip against the beat, bright lydian sparkle on top.` |
| **gauntlet** | 8 | A long run of tight choices, no letup. | `Driving but soft. A steady 16th-note plucked pulse over a gentle four-on-the-floor kick. Determined, always moving forward, never stopping.` |
| **knot** | 4 | Roads tangled over the whole map. | `Interlocking arpeggios weaving over each other, marimba and guitar in three-against-four. Minimalist, intricate, tidy.` |
| **restock** | 5 | Pickups: the van keeps getting topped up. | `Bouncy and cheerful. Marimba and a little shop bell, syncopated, a stop-start groove that keeps refilling itself.` |
| **sorter** | 5 | A spinner swaps your top two packages. | `Swirling, like a carousel. A circular melody that turns back on itself, triplets rolling over the 4/4. Soft organ and vibraphone.` |
| **park** | 4 | Parking lockers: put it down, come back for it. | `Laid-back. The melody is stated, set aside, and comes back later. Upright bass with stop-time breaks: little pauses, then it picks up where it left off.` |
| **hoard** | 3 | The Baron's huge warehouse jobs, at the very end. | `Big and heavy but slow. Deep bass, a low brass section, soft tom drums and muted warehouse clanks, layers stacked high. Grand, a little absurd.` |

### Everything else

| Song | Where | Why | Add to the style |
|---|---|---|---|
| **boss** | The Baron's jobs | A cringe billionaire who takes losing personally. | `A villain's theme, mock-pompous. D minor. A hint of tango and march, bassoon and low brass, a sneering muted trumpet. Comic menace, never scary.` |
| **daily** | The daily puzzle | One puzzle a day, no hints. | `The morning paper's puzzle over coffee. Crisp café jazz: brushed drums, upright bass, vibraphone lead. Bright and alert.` |
| **speedrun** | Speedrun courses | Against the clock. | `Urgent and quick: double-time feel, racing 16th-note hi-hats kept soft, a ticking clock, energetic funk bass. Still low in the mix.` |

### Detours (optional: only if you want them to have their own)

| Song | Detour | Add to the style |
|---|---|---|
| **fog** | Fog Bank | `Muffled and distant, as if heard through fog. Everything low-passed, soft foghorn-like low brass notes, slow.` |
| **melt** | Before It Melts | `Warm and woozy, slowly drooping. Notes that bend downward like something melting. Steel-drum-like plucks, summery.` |
| **fuel** | Small Tank | `Sparse and careful, running on fumes. Very few notes, long gaps, a nervous little shaker.` |
| **noBrakes** | No Brakes | `Reckless and gleeful, never pausing for breath. A galloping bass line, runaway banjo-like plucks.` |
| **mega** | Twin Towns, The Big Map | `Wide and expansive, a long road ahead. Slow-moving chords, slide guitar, big open reverb.` |

## The three variants

Add one of these lines when making B and C from A. The point is "the same song, slightly different", not a new
song.

- **B, lighter:** `Variation of the same tune and chords: the melody moves to vibraphone, and the drums drop to just finger snaps and a shaker.`
- **C, fuller:** `Variation of the same tune and chords: the melody is an octave lower on clarinet, with a quiet counter-melody and hand percussion added.`

For **daily**, use the variants as the three spice levels instead:

- **A, mild:** the prompt as written.
- **B, medium:** `Same tune, a little busier: add a walking bass line and a second vibraphone answering the first.`
- **C, spicy:** `Same tune, more heat: quicker brushed drum fills, a more restless bass, and the melody in tighter, faster phrases.`

## If 51 tracks is too many

Start with the six flavours that cover 68 of the 100 jobs: **intro, melter, twodoor, decoy, longcon, gauntlet**
(18 tracks). The rest can share the nearest one until they have their own:
practice with intro, twin with twodoor, breather and park with longcon, knot and sorter with melter,
restock with decoy, hoard with gauntlet.

## Bringing them back

- Export **MP3** (the game plays it as it is, and it's small). WAV is fine too.
- Name them `<song>_a`, `<song>_b`, `<song>_c` (for example `melter_b.mp3`) and drop them in `audio/music/`.
- Don't trim or edit them. Claude measures each one's tempo and where its bars fall, then sets up the mixing:
  the next song comes in on the bar, at the same speed, and the old one fades under it; and a job never gets
  the variant it had last time.
- Check your plan's terms before this ships: these tools usually only allow commercial use of tracks made on
  a paid plan.
