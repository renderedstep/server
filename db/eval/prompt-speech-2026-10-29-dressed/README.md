# prompt-speech-2026-10-29-dressed

What somebody said unasked, narrated: the seven speech cases, four repetitions
on `mistralai/mistral-medium-3.1`. It replaces `prompt-speech-2026-09-28`,
which stays as history and is this set's before side.

**The change.** The protagonists' clothes became worn item records, and the
narrator is told what the player is wearing. Moved:
- the request identity: `v1:db3738cb48b47a41` -> `v1:5f47190d8ae7378a`;
- the prompt digest: `5e980aaef84ffe6a` -> `7219f268d85268f4`.

The instructions (`b7473fa259e8f5cf`) and the corpus (`49d49c3629a6245a`) did
not. Bought at server `4a77e5c` on engine `8840009`.

**The verdict.** Every check reads NOISE. `item_not_held` goes 0.071 -> 0.000.
`latency_median` 1.66s -> 1.81s reads REAL. The before side is a month older,
so that reads as the provider rather than the change, and it is not proven
either way.

```sh
rake eval:prompt_compare CORPUS=speech BEFORE=prompt-speech-2026-09-28 AFTER=prompt-speech-2026-10-29-dressed
```

**Read by hand.**
- **Before:** 8 of 28 readings mention clothing. Every one is somebody
  else's: Sub-Inspector Rowe's grey coat, or the justicar's gown, as their
  appearance lines describe them.
- **After:** 6 readings. Five are Rowe's coat. In one `speech-warn-way`
  reading the player's own oilskin "catches the wind" (Coraith Vell's, now a
  worn record the narrator is told).
- In no reading on either side is a worn thing taken off, dropped or put on.

**Cost.** `receipts.json`: 29 calls including the warm-up, $0.0161 at the
registry's rate, against $0.04 authorized. The bench printed $0.0155 for the 28
measured calls. The key's usage moved $0.026930 across the run, settled before
and after; that is an upper bound, because the key is shared.

A first start of this run was stopped in its first repetition, by a guard that
read the ending run's late-arriving spend as this run's. Nothing from it is
kept.
