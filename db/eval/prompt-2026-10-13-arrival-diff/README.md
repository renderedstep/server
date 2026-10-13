# prompt-2026-10-13-arrival-diff

The main prompt corpus, re-bought at four repetitions on the shipped model
after a return began to tell the arrival writer what changed since the game
last left the room (the engine's `revisit`), or that the game kept no record
of leaving it.

No instruction to the narrator changed. Six of the corpus's twelve `move`
cases walk back into a room this game has stood in: `move-back-to-court`
(the designated `move` case), `move-back-to-court-full`,
`move-back-to-office`, `move-back-to-office-plain`, `move-closet-swept-clean`
and `move-to-court-slate-down`. No staged position holds a record of the
departure, so each takes the no-record branch. Its arrival request no longer asks for "what has changed
while they were gone, or what pointedly has not", and says instead that the
game kept no record of what was there when they left, so nothing is to be
narrated as changed. Every other case sends the bytes it sent under
`prompt-2026-09-28-reactions`, the baseline this replaces.

`rake eval:prompt_compare BEFORE=prompt-2026-09-28-reactions AFTER=prompt-2026-10-13-arrival-diff`
is recorded below. Every figure reads NOISE. Every flagged reading in this
set is on a take, examine or read case, none of which walks into a room, so
their requests did not move.

The bench accounted $0.2097 over 360 calls. The key's usage moved $0.2137
across the run, an upper bound because the key is shared (`receipts.json`).

```
------------------------------------------------------------------------------
PROMPT BENCH: prompt-2026-09-28-reactions -> prompt-2026-10-13-arrival-diff
Exact rank test at p <= 0.05, 4 repetitions a side minimum.
------------------------------------------------------------------------------
schema request: v1:9a85b9d4a0c663ab
prompt-2026-09-28-reactions: mistralai/mistral-medium-3.1 | corpus dfd1756a8f1f91b8 | prompt d9cbba88a8e3eecb | 4 reps
schema request: v1:860ea6a9b1d5b342
prompt-2026-10-13-arrival-diff: mistralai/mistral-medium-3.1 | corpus dfd1756a8f1f91b8 | prompt f4b1c5cf6ee191b6 | 4 reps
Latencies are WARM-CACHE figures -- each arm's first call is timed apart and excluded.

This is a PROMPT comparison on one model: d9cbba88a8e3eecb -> f4b1c5cf6ee191b6.

MODEL  mistralai/mistral-medium-3.1
  unrecorded_departure       0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  unrecorded_arrival         0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  item_not_held              0.033 -> 0.061  WORSE     NOISE (inside the 0.056 the unchanged runs already spanned)
  take_denied                0.056 -> 0.028  BETTER    NOISE (inside the 0.056 the unchanged runs already spanned)
  pickup_invented            0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  inscription_misquoted      0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  truncated_prose            0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  third_person_protagonist   0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  blow_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  toll_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  throw_contradicted         0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  body_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  beat_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  refusals                   0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  failures                   0 -> 0  BETTER    NOISE (inside the 1.000 the unchanged runs already spanned)
  omitted_fields             0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  cap_hits                   0 -> 0  BETTER    NOISE (inside the 1.000 the unchanged runs already spanned)
  latency_median             1.60s -> 1.61s  WORSE     NOISE (inside the 0.067 the unchanged runs already spanned)
  latency_p95                2.15s -> 2.20s  WORSE     NOISE (inside the 0.191 the unchanged runs already spanned)
  output_tokens              12749 -> 12693  reported  NOISE (inside the 342.000 the unchanged runs already spanned)
  words                      98 -> 97  reported  NOISE (inside the 2.000 the unchanged runs already spanned)
  commitments                3.374 -> 3.422  reported  NOISE (inside the 0.264 the unchanged runs already spanned)

A REAL verdict on a CHECK is what means a prompt change worked. Read `commitments`
beside it: a fall in every rate with a fall in that is prose that says less, which is
the one way to improve these numbers without improving the game (Eval::Richness).
Everything INCONCLUSIVE at these sample sizes means: not enough repetitions.
Confirm a REAL verdict with `rake eval:run` before believing it.
------------------------------------------------------------------------------
```
