# The realization baseline with the people already standing in a room named

The current before side for `Location::Generator`'s prompts:
`mistralai/mistral-medium-3.1`, four repetitions, all 29 cases. It replaces
`realization-2026-10-02`, which stays as history.

What moved is the detail prompt, and only for a room that somebody already
stands in before it is written. Such a room gets an "Already Standing Here"
block naming each person in it. The people line asks for new people "besides the
people Already Standing Here above", or, when the room drew nobody new, says
"Write NOBODY new into this place. The people Already Standing Here above are
everyone who is here." A room nobody stands in is asked exactly what it was
before. One corpus case is such a room: `dead-end`'s The Tide Post, with Neb
Halloran in it. The other eight shapes' prompts are byte-identical to the
2026-10-02 set's.

## Verdict against the side before

Against `realization-2026-10-02`, every check read NOISE, so no check moved
outside the spread the unchanged runs already showed. Three reported figures
read REAL: `hazard_on_the_ground_floor`, `hazard_below_ground` and
`things_furnished` (10.00 -> 10.03). Each is a fact about the staged world's
rooms rather than about the writer's answer, and none of them reads the
people block.

```sh
rake eval:realization_compare BEFORE=realization-2026-10-02 AFTER=realization-2026-10-27
```

`receipts.json` holds the spend: the provider's credits moved by $0.297, and
the bench priced the run at $0.369 from the model registry.
