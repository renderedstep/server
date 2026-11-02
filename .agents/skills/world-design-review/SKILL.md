---
name: world-design-review
description: Review a world file, floor schedule, arc or world-generation change for design — playability, fairness, pacing, layout and variety — against VISION.md and the engine's own checks. Use when authoring or reviewing db/seeds/worlds/*.yml or lib/engine_sweep/worlds/*.yml, a floor: block, guards, an arc, or anything that decides what a world contains; not for prompt wording (that is EVALUATION.md's).
---

# Review a world for design

A world is the one place a design mistake becomes durable: a place is generated
once and kept, so a world file that cannot be finished, or that kills a player
without warning, stays that way for every game played in it. This skill asks
the design questions of a world and insists that every answer rests on
something the engine or a command can show.

**Evidence is a doctor finding, a sweep assertion, a fight-simulator result or
a lab score — never "it reads better".** A claim with none of those behind it
is labelled a hand trace, and says so. This is the project's standing
constraint (`AGENTS.md`, "The standing constraint") applied to design.

## The rulings come first

Read these before any lens below; a lens never outranks them. Where outside
design advice (`references/principles.md`) disagrees with a ruling, the ruling
stands and the review says so rather than reopening it.

- [VISION.md](../../../VISION.md), guiding principles 1 (the engine is the
  source of truth; models never set a number), 2 (the narrator is never told
  the dice), 5 (danger is real), 6 (worlds stay varied; the engine's dice place
  things, not the file), 7 (a place is generated once and left alone; the
  engine may only *add* a person or enemy), 8 (hand-made worlds meet the same
  standard as generated ones), and the non-goals.
- [AGENTS.md](../../../AGENTS.md): "A world supplies parameters, never
  behaviour"; a new per-row parameter ships inert; "Adding a parameter to a
  checked-in world changes every sweep script that walks it"; "An engine change
  earns a sweep script, not only a unit test".
- The world file's own format and its rules: `db/seeds/worlds/README.md`.

## The lenses

Each lens is a question, where to look for the answer, and what counts as
evidence. Not every lens applies to every change; say which were skipped and
why.

### Goal and legibility — does the player always know what the story asks of them?

- **Look at:** the arc (`quests:` and their steps), and the doctor's playability
  properties P1–P4 in the header above `Story::Doctor#unreachable_quest_targets`
  (`app/models/story/doctor.rb`).
- **Ask:** does the goal exist as a row before the frontier runs out (P1)? Does
  the frontier keep pointing at it (P2)? Is there an ending to reach (P4)? Is
  there more than one way to learn where the next beat is — the glance's next
  beat, a person who knows (`app/models/character/desires.rb`), the direction
  the exits point?
- **Evidence:** `rake game:doctor` on the loaded world, with no finding from
  `#unbound_quest_steps`, `#stories_that_cannot_progress`,
  `#frontier_turned_away_from_the_goal` or `#quests_without_an_outcome`.

### Fairness — Tough, never Nasty

On Plotkin's cruelty scale (see `references/principles.md`) a game with
permadeath is at best *Tough*: you can get stuck, but it is obvious beforehand.
*Nasty* — the cause is only obvious afterwards — is a defect.

- **Look at:** every way this world can end a game: zero hit points, a floor
  falling, a toll on a doorway (`app/models/playthrough/hazards.rb`,
  `app/models/playthrough/toll.rb`), a deadline (`app/models/quest/deadline.rb`).
- **Ask:** for each one, where does the player see it coming *in the engine's
  own words*? The narrator is never told dice or checks, so the warning cannot
  be left to prose: it has to be a glance line, a refusal
  (`app/models/playthrough/refusal.rb`) or the end notice
  (`app/models/playthrough/end_notice.rb`). After this death, could the player
  say what they would do differently? Is every fight escapable by leaving?
- **Evidence:** a sweep script that walks to the danger and asserts the warning
  appears before it lands (`lib/engine_sweep/scripts/`; see
  `a-floor-falls-behind-you.yml` and `death-ends-a-playthrough.yml` for the
  shape).

### Layout — can it be finished, and is it worth walking?

- **Look at:** `locations:` and `connections:` (their `barrier` and
  `key_template`), a
  `floor:` block (`rooms`, `down`, `guards`), and how the engine lays a floor
  out — the header of the pinned engine's `src/floor.rs` and `src/interior.rs`
  (the pin is in `ext/renderedstep/Cargo.toml`).
- **Ask:**
  - **Is every key reachable without first passing the lock it opens?** This
    is the softlock a dependency chart exists to catch. The doctor's
    lock-aware reachability finding answers it; run `rake game:doctor`. Where a
    question it does not cover remains, trace it by hand and label the trace.
  - **What is the critical path** from arrival to the goal or the way down,
    and is anything on it a guess?
  - **Is there more than one way?** Loops spare backtracking. A floor gets
    loops by construction (extra doors in `src/interior.rs`); a hand-written
    world gets them only if its `connections:` draw them. A deliberately
    linear chain of locks — one per floor, key beside its lock — is a valid
    crawler shape; say so rather than "fixing" it.
  - **Does a dead end pay?** A long branch that ends in nothing is a cost.
  - **Is any of it a maze** — rooms that differ in fact but not in what the
    player can tell apart? Placeholder room names are where that creeps in.
- **Evidence:** the doctor; a sweep script that walks the critical path to
  its end (see `two-floors-and-a-key.yml`, `a-guarded-stair.yml` and
  `a-key-for-the-other-door.yml` under `lib/engine_sweep/worlds/` for keyed
  layouts, and `a-floor-laid-out-to-its-count.yml` under
  `lib/engine_sweep/scripts/`).

### Pacing — where are the valleys?

The engine may add a threat but never remove one (VISION principle 7), so the
"relax" half of a tension cycle cannot come from the engine taking enemies
away. It has to be built into the place.

- **Look at:** safe rooms (`safe_rooms` in a `floor:` block; nothing hostile is
  born in one), rest (`resting-in-a-safe-room.yml`), a floor's countdown
  (`waiting-out-a-floor.yml`), scheduled events (`app/models/world_event.rb`).
- **Ask:** after each peak, is there somewhere to recover, and can the player
  reach it? Is the countdown-versus-rest trade visible, so resting is a choice
  rather than a trap? If a threat is injected into a room already generated,
  is it foreshadowed — through a doorway the player can see, announced in the
  engine's words — rather than appearing whatever route was taken?
- **Evidence:** a sweep script that walks the trade (rest, then see the clock);
  for anything the engine does not yet do, an owner's-call finding, not an
  assertion.

### Variety — does each place feel like a different place?

- **Look at:** what the file fixes and what it leaves to the engine's dice
  (VISION principle 6). On a floor, every room shares the floor's `danger` and
  `hazard`; kinds are dealt per room and the room writer names and describes
  each.
- **Ask:** is sameness a risk here? Is anything preset in the file that the
  engine should roll?
- **Evidence:** do not judge generated prose yourself. Ask the owner for a lab
  sample (`app/models/lab/realization.rb`, `app/models/lab/exits.rb`;
  `rake eval:realization`), which the owner scores. Prompt wording that a
  sample points at is EVALUATION.md's, not this skill's.

### Difficulty — is every number checked?

- **Look at:** guard and boss stats, a floor's level, healing and safe-room
  counts, minutes on a clock, rest.
- **Ask:** was this number chosen by running the engine's fight simulator, with
  the target stated before the run?
- **Evidence:** a simulator run attached to the change. Every difficulty number
  goes to the engine repository's `fight-numbers` skill; never estimate one
  here, and never ask a model for one (VISION principle 1).

### Every lens — what is the player deciding?

A fight leaves few choices inside it by design; the interesting ones are
outside it: whether to enter, to run, to drink now or later, to rest while the
clock runs, which way to go. For each feature, name the decision it creates and
whether the player can see what they need to make it. A feature that serves no
decision and none of the aims in VISION's purpose is a candidate to cut.

## Output

Sort every finding into one of three groups, each with its evidence or its
labelled hand trace:

1. **The engine already enforces this** — name the check (a doctor method, a
   loader validation, an engine invariant) so nobody re-litigates it.
2. **A doctor finding or a sweep should enforce this** — a candidate backlog
   item: the property, the world that would trip it, and where the check
   belongs (`app/models/story/doctor.rb` or a script under
   `lib/engine_sweep/scripts/`).
3. **The owner's call** — a decision with its options, the ruling it touches,
   and what each option costs. Do not decide these.

Lead with anything that makes the world unfinishable or unfair; style comes
last.

## References

- `references/principles.md` — the design research behind each lens, every
  entry with its source.
- `references/borrowed.md` — checklist items adapted from MIT and Apache-2.0
  licensed skills, with their licence notices.
