# Design principles behind the lenses

Outside game-design and level-design writing that the lenses in `SKILL.md`
draw on, each with its source and where it bears on this game. These are
review questions, never rules: where one disagrees with a ruling in
`VISION.md` or `AGENTS.md`, the ruling stands, and the entry says so.

## Text adventure and interactive-fiction craft

**The Bill of Player's Rights.** Graham Nelson, *The Craft of Adventure*
(1995), https://www.ifarchive.org/if-archive/info/Craft.Of.Adventure.txt.
Among them: "Not to be killed without warning", "Not to have the game closed
off without warning", "To have a good reason why something is impossible",
"To know how the game is getting on", "Not to depend much on luck", "To be able
to win without experience of past lives".
*Here:* warnings and reasons come from the engine's own words — refusals
(`app/models/playthrough/refusal.rb`), the glance, the end notice
(`app/models/playthrough/end_notice.rb`) — because the narrator is never told
the dice (VISION principle 2). "Not to depend much on luck" and "win without
past lives" meet "Danger is real" (VISION principle 5) and permadeath: the
rulings stand. The lever is information, not fewer dice; what a past life
teaches should be knowledge of the place, never a requirement.

**The cruelty scale.** Andrew Plotkin, https://www.ifwiki.org/Cruelty_scale.
Merciful ("Can never die or get stuck"), Polite ("Can die, but cannot get
stuck"), Tough ("Can get stuck, but this is obvious beforehand"), Nasty
("…obvious afterward"), Cruel ("…not obvious afterward").
*Here:* with permadeath, a death is being stuck, so the target is Tough:
every ending obvious beforehand. The fairness lens.

**Rules of thumb.** Ron Gilbert (1989),
https://grumpygamer.com/why_adventure_games_suck. "End objective needs to be
clear", "Sub-goals need to be obvious", "Real time is bad drama", "Reward
intent", "Give the player options", "Live and learn".
*Here:* a clear goal is the doctor's P1 and P2 (`app/models/story/doctor.rb`,
the playability header). A floor's countdown runs on story time, which moves
only when the player acts, so it is a resource rather than a real-time clock.
"Live and learn" (no death needed to learn) meets VISION principle 5; the
ruling stands, and "obvious beforehand" is the bridge.

**Puzzle dependency charts.** Ron Gilbert (2014),
https://grumpygamer.com/puzzle_dependency_charts. "Flowcharts are great if
you're trying to solve a game, dependency charts are great if you're trying to
design a game." The chart shows what must happen before what; its warning
signs are a chart too linear, and dead ends.
*Here:* an arc's steps and a world's keyed doorways together are such a chart.
The layout lens's key-before-its-lock question comes from here.

**Mazes.** Nelson, same source: "Difficulty and tedium shouldn't be the goal";
offer a shortcut, or omit the maze.
*Here:* a large floor whose rooms the player cannot tell apart is a maze in
effect, whatever the layout code guarantees.

**A model as the parser.** intfiction.org, "Why can't the parser just be an
LLM?" (2023), https://intfiction.org/t/why-cant-the-parser-just-be-an-llm/64001.
Replies point to the "lack of world state" and favour a model layer that maps
commands onto the game's own events.
*Here:* that is this project's standing constraint (`AGENTS.md`): the model
picks from a closed set and the engine acts.

## Dungeon and level layout

**Xandering (formerly "Jaquaying") the dungeon.** Justin Alexander (2010),
https://thealexandrian.net/wordpress/13085/roleplaying-games/jaquaying-the-dungeon.
Multiple entrances, multiple paths between levels, loops, so that "the
environment isn't forcing them along a pre-designed path".
*Here:* the "more than one way" question. A floor gets loops from the extra
doors in the engine's `src/interior.rs`; a way between floors is whatever the
world file draws.

**Missions and spaces.** Joris Dormans, "Adventures in level design:
generating missions and spaces for action adventure games" (PCG workshop
2010), https://doi.org/10.1145/1814256.1814257; the cyclic generator of
*Unexplored*, explained by Boris the Brave,
https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/.
Generate what must be done (locks and keys) apart from the space, then fit one
to the other; Unexplored keeps an edge from each key to its lock so a blocked
path can be detected.
*Here:* the world file and arc are the mission and the engine's floor layout is
the space. The doctor reads a key and its lock as a check, never as a
mechanism that changes a world.

**Lock-and-key graphs.** Mark Brown's "Boss Keys" notation, summarised in Boris
the Brave, "Lock and Key Dungeons" (2021),
https://www.boristhebrave.com/2021/02/27/lock-and-key-dungeons/. A tall, thin
graph is a linear dungeon, and many that feel complex are fixed-order beneath.
*Here:* a chain of floors, each key beside its lock, is linear by design; a
review names that rather than "fixing" it.

**A guaranteed solution path first.** Darius Kazemi on Spelunky's generator,
http://tinysubversions.com/spelunkyGen/. Trace the solution path, then fill the
rest with rooms that cannot block it.
*Here:* the engine guarantees a floor's rooms are connected (the header of its
`src/floor.rs`); the critical path's *length* is not controlled, and is a
pacing fact to measure, not a defect.

**Generate, test, discard.** Josh Ge (Cogmind),
https://www.gridsagegames.com/blog/2014/06/procedural-map-generation/: "A map
with few or no loops in its layout will require lots of backtracking, and
backtracking is not fun!" and "Long paths that lead to dead ends had better at
least contain treasure or access to a new area."
https://www.gridsagegames.com/blog/2019/03/roguelike-level-design-addendum-procedural-layouts/:
reachability and shape are tested on completion and the map thrown out if out
of range.
*Here:* the doctor and the sweeps are the test half. Discarding a layout would
change every floor's dice; that is the owner's call, not a review fix.

**The five-room dungeon.** Johnn Four, Roleplaying Tips (2006),
https://www.roleplayingtips.com/rptn/5-room-dungeons-contest/. Entrance and
guardian; puzzle; setback; climax; reward or twist.
*Here:* a vocabulary for what the people on a small floor are for. The engine
still lays the rooms out.

**Ten principles of good level design.** Dan Taylor (GDC 2013),
https://www.gamedeveloper.com/design/ten-principles-of-good-level-design-part-1-
and https://www.gamedeveloper.com/design/ten-principles-of-good-level-design-part-2-.
Among them: "tells the player what to do, but not how to do it", "is
surprising", "lets the player control the difficulty".
*Here:* surprise is VISION principle 7; controlling the difficulty is the
countdown-versus-rest trade.

## Pacing, difficulty and fairness

**Adaptive dramatic pacing.** Michael Booth, "The AI Systems of Left 4 Dead"
(AIIDE 2009),
https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf.
A director cycles Build Up, Sustain Peak, Peak Fade and Relax; Relax holds a
minimal threat "until Survivors have traveled far enough toward the next safe
room".
*Here:* the relax phase *removes* threats, and VISION principle 7 lets the
engine only add one. The ruling stands, so the valleys come from layout: safe
rooms and escapable fights.

**Interesting decisions.** Sid Meier (GDC 2012),
https://gdcvault.com/play/1015756/Interesting. "Good decisions are
situational."
*Here:* the "what is the player deciding?" question asked of every lens.

**Failure that feels like your own.** Jesper Juul, *The Art of Failure* (MIT
Press, 2013),
https://www.jesperjuul.net/ludologist/2013/02/25/the-art-of-failure/.
*Here:* permadeath motivates only if the player can see why they died — the
end notice and the engine's own act lines.

**The Three Clue Rule and the quantum ogre.** Justin Alexander, "Three Clue
Rule" (2008),
https://thealexandrian.net/wordpress/1118/roleplaying-games/three-clue-rule;
"Smart Prep",
https://thealexandrian.net/wordpress/39893/roleplaying-games/smart-prep-part-2-the-principles-of-smart-prep;
Hack & Slash, "On Slaying the Quantum Ogre" (2011),
http://hackslashmaster.blogspot.com/2011/09/on-slaying-quantum-ogre.html:
"Without information, they cannot make a choice with intent."
*Here:* more than one route to knowing where a goal is; an added enemy
foreshadowed rather than placed whatever the player chose.

## Generation that stays playable

**The 10,000 bowls of oatmeal.** Kate Compton, "So you want to build a
generator…" (2016),
https://galaxykate0.tumblr.com/post/139774965871/so-you-want-to-build-a-generator:
"Perceptual uniqueness is the real metric, and it's darn tough."
*Here:* the variety lens. Perceived sameness is measured by a lab sample the
owner scores, not by a reviewer's reading.

**Expressive range.** Gillian Smith and Jim Whitehead, "Analyzing the
expressive range of a level generator" (PCG workshop 2010),
https://doi.org/10.1145/1814256.1814260. Plot many generated artifacts on two
metrics to expose a generator's biases.
*Here:* the method for measuring what a layout does across seeds, offline.

**The PCG textbook.** Shaker, Togelius and Nelson, *Procedural Content
Generation in Games* (2016), https://www.pcgbook.com/. Constructive,
search-based and constraint-based generation, and evaluating generators.
*Here:* the engine's floor layout is constructive with guarantees; the doctor
and sweeps are the test of generate-and-test.

**LLM-built worlds.** Word2World (Nasir, James and Togelius, 2024),
https://arxiv.org/abs/2405.06686, checks playability with an agent that plays
the world — what `lib/engine_sweep/` does. Story2Game (Zhou et al., 2025),
https://arxiv.org/abs/2505.03547, has a model write the game's action code;
that breaks "A world supplies parameters, never behaviour" (`AGENTS.md`) and is
the road not taken.

**MDA.** Hunicke, LeBlanc and Zubek (2004),
https://users.cs.northwestern.edu/~hunicke/MDA.pdf. Designers reason from
mechanics to dynamics to aesthetics; players meet them the other way round.
*Here:* VISION's "fun, exciting and heartbreaking", with companions not all of
whom make it, is Challenge, Narrative, Discovery and Fellowship; a feature that
serves none of them is a candidate to cut.
