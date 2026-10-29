# Vision

Covers the game (renderedstep/server), its Rust engine (renderedstep/engine) and the terminal client (renderedstep/terminal).

**Purpose.** A testbed for experimenting with language models in a game: learning what is possible, especially with smaller models, and learning and distilling story structure and pacing. It is a game generator more than a place to play: each story is settled with its author over several exchanges about its world, its universe and its people, and then built as its own game. The games are meant to be fun, exciting and heartbreaking. You meet companions you come to love, and not all of them make it. Each game is a text adventure that writes its world as you play and keeps it: a living place whose rules are kept by the engine, and whose prose comes from a model. Anything a person could do in real life, a player can do there: acting on the world changes it, in the engine's own state, and the people in it notice. Wreck your room at the inn, and the innkeeper or the housekeeper will find it and be angry about it.

**Who it is for.** First the developer, then people who want to make a story into a game, and the invited players who want a fair, surprising, moving story they can type freely into.

**In 1-2 years.**
- A story is created over several exchanges, not from a single prompt: the author and the generator go back and forth to settle the world, its universe and its people before it is built.
- Clients can run a generated game on their own, with the engine bundled, a local world and a small local reader for typed lines. The server generates games, syncs shared worlds and saves between clients and stays a playable web client, the main one for now.
- Characters act from their own desires.
- Companions join the player, can be loved, and can be lost; whether one survives is an outcome the engine keeps, never the narrator's choice.
- Characters notice what the player has changed in the world, and react to it.
- Every world is checked playable: a goal, someone to talk to, an ending. The player always knows what the story asks of them, and an ending is never a surprise: the player confirms it, and the game says why it happened.
- Model costs are near zero per turn.

**Guiding principles.**
1. The engine is the source of truth. Models pick from lists the engine supplies, and never set a number the engine can roll or decide who lives. An act the game understands changes the world's state; nothing is only narrated.
2. The narrator is told what was tried and whether it worked, never the dice, checks or numbers behind it. A simple act the engine settles is told in one short sentence of the engine's own; prose is for what the records cannot say.
3. The player is offered only what is possible from where they stand and what is within reach.
4. One line, one act. When the game is unsure what a line means, it refuses and asks rather than guess: doing what the player did not intend is worse than not understanding them. Refusals are kept to improve the reader, and refusing is never a stopgap. A line with only one sensible reading in that place is read without a model.
5. Danger is real. A risky choice the rules allow is not refused, and its consequence lands, even when it is fatal.
6. Worlds stay varied and unexpected. The engine's dice decide what is placed, guarded or hidden as a world is built or played; none of it is preset in a file. Places feel lived in: people wear and carry things, rooms hold things, and things outnumber people.
7. Hand-made worlds meet the same standard as generated ones. A problem or feature found while playing one updates that world in the same change, restarting its game if it must but keeping it if it can; the other worlds follow soon after.
8. Measure before changing: one variable at a time, against a stored baseline.
9. Build the intended design directly, in small measured stages. Nothing is built only to be thrown away.
10. Small and local before large and hosted.
11. Everything published is plain, licensed and free of private data.

**Non-goals.** Graphics; a crunchy RPG ruleset (classes, spells, armour); multiplayer in one shared room; a model trusted to keep state; an app store or package-manager presence for now.
