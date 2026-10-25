# Vision

Covers the game (renderedstep/server), its Rust engine (renderedstep/engine) and the terminal client (renderedstep/terminal).

**Purpose.** A testbed for experimenting with language models in a game: learning what is possible, especially with smaller models, and learning and distilling story structure and pacing. The game itself is a text adventure that writes its world as you play and keeps it: a living place whose rules are kept by the engine, and whose prose comes from a model. Anything a person could do in real life, a player can do there: acting on the world changes it, in the engine's own state, and the people in it notice. Wreck your room at the inn, and the innkeeper or the housekeeper will find it and be angry about it.

**Who it is for.** First the developer, then invited players who want a fair, surprising story they can type freely into.

**In 1-2 years.**
- Clients can run the game on their own, with the engine bundled, a local world and a small local reader for typed lines. The server syncs shared worlds and saves between them and stays a playable web client, the main one for now.
- Characters act from their own desires.
- Characters notice what the player has changed in the world, and react to it.
- Every world is checked playable: a goal, someone to talk to, an ending.
- Model costs are near zero per turn.

**Guiding principles.**
1. The engine is the source of truth. Models pick from lists the engine supplies, and never set a number the engine can roll.
2. One line, one act. Refuse or ask, rather than guess.
3. Measure before changing: one variable at a time, against a stored baseline.
4. Small and local before large and hosted.
5. Everything published is plain, licensed and free of private data.

**Non-goals.** Graphics; a crunchy RPG ruleset (classes, spells, armour); multiplayer in one shared room; a model trusted to keep state; an app store or package-manager presence for now.
