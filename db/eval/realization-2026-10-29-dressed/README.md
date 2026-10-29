# The realization baseline after the hand-made worlds were dressed

The current before side for `Location::Generator`'s prompts:
`mistralai/mistral-medium-3.1`, four repetitions, all 29 cases. It replaces
`realization-2026-10-27`, which stays as history and is this set's before
side.

**What moved.** The three protagonists' appearance lines lost their clothes,
which became worn item records. No instruction moved. The room writer's cast
lines read a person's appearance, so four of the nine shapes' prompts moved:
`dead-end`, `two-ways-out`, `unwritten-neighbour` and `written-neighbour`.
- request identity: `v1:96df4e50432ded45` -> `v1:d8295c3a19509407`;
- prompt digest: `2bd7ededf340aaee` -> `cee829a60a8515b1`.

The instructions (`d43b9ecd17181013`) and corpus (`85db33ab0b9f2f9c`) did
not. The NPCs keep their appearance lines exactly as before. Bought at server
`4a77e5c` on engine `8840009`.

## Verdict against the side before

Every check reads NOISE, so no check moved outside the spread the unchanged
runs already showed:

```sh
rake eval:realization_compare BEFORE=realization-2026-10-27 AFTER=realization-2026-10-29-dressed
```

- Two reported figures read REAL:
  - `hazard_on_the_ground_floor` 0.500 -> 0.200;
  - `hazard_below_ground` 0.308 -> 0.750.
- These are facts about the staged world's rooms, not about the writer's
  answer. The same two figures read REAL against the set before this one,
  where nothing a hazard reads had changed either.
- `people_named`, `people_offered`, `exits_named` and `things_furnished` are
  unchanged.

## Cost

`receipts.json`:
- The bench priced the run at $0.3470 from the model registry.
- The provider's credits moved $0.359792 across the run, settled before and
  after. That is an upper bound, because the key is shared.
- Cap: $0.45.
