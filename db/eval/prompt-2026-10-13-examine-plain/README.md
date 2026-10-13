# prompt-2026-10-13-examine-plain

The main prompt corpus, re-bought at four repetitions on the shipped model
after a look at a thing with nothing written on it began to hand the narrator
the thing's own description (engine `facts::examined`). The fact also says
where the thing is now and that the look moved nothing, and the turn now
carries the `examine` doing line.

No instruction to the narrator changed. Seven `examine` cases look at a plain
thing: `examine-stamp-plain`, `examine-stamp-ink`, `examine-stamp-alone`,
`examine-stamp-in-hand`, `examine-apron-plain`, `examine-apron-carried` and
`examine-apron-fold`. Only their requests moved. Every other case sends the
bytes it sent under `prompt-2026-10-13-arrival-diff`, the baseline this
replaces.

`rake eval:prompt_compare BEFORE=prompt-2026-10-13-arrival-diff AFTER=prompt-2026-10-13-examine-plain`
is recorded below. Every check reads NOISE. `words` reads REAL (97 to 95), but
the 83 unchanged cases also fall (median 97 to 94), so most of that is the model's
own spread. On the seven moved cases, paragraphs get longer (mean 104 to 121
words) and name fewer of the room's rooms, exits, items and people (mean
commitments 3.14 to 2.14). They describe the thing instead of the room.

No check counts an invented look, so the 28 moved paragraphs a side were read
by hand:

- **The stamp** (`examine-stamp-*`, 16 readings a side). Its description says
  the ink on the pad is still wet. Before, eight readings mention the ink, and
  all eight call it dry. After, all sixteen keep it wet.
- **The apron** (`examine-apron-*`, 12 readings a side). Its description says
  it was folded to the size of a book, and refolded by somebody who did it in
  the dark. Before, no reading says so. All four `examine-apron-plain`
  readings lift the apron off the shelf, one of them stitches initials on it,
  and the carried ones drape it over the player's arm. After, all twelve tell
  the fold in the dark or by touch, and no `examine-apron-plain` reading lifts
  it.
- **Known regression.** Three of four `examine-apron-carried` readings unfold
  the carried apron a little, though the fact says the look moved nothing.
  Before, none did.

The bench accounted $0.2015 over 360 calls. The key's usage moved $0.2045
across the run, which also takes in a 7-call trial. That is an upper bound
because the key is shared (`receipts.json`).

```
------------------------------------------------------------------------------
PROMPT BENCH: prompt-2026-10-13-arrival-diff -> prompt-2026-10-13-examine-plain
Exact rank test at p <= 0.05, 4 repetitions a side minimum.
------------------------------------------------------------------------------
schema request: v1:860ea6a9b1d5b342
prompt-2026-10-13-arrival-diff: mistralai/mistral-medium-3.1 | corpus dfd1756a8f1f91b8 | prompt f4b1c5cf6ee191b6 | 4 reps
schema request: v1:77f94a8426ff4d58
prompt-2026-10-13-examine-plain: mistralai/mistral-medium-3.1 | corpus dfd1756a8f1f91b8 | prompt 511524f8e7097191 | 4 reps
Latencies are WARM-CACHE figures -- each arm's first call is timed apart and excluded.

This is a PROMPT comparison on one model: f4b1c5cf6ee191b6 -> 511524f8e7097191.

MODEL  mistralai/mistral-medium-3.1
  unrecorded_departure       0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  unrecorded_arrival         0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  item_not_held              0.061 -> 0.050  BETTER    NOISE (inside the 0.056 the unchanged runs already spanned)
  take_denied                0.028 -> 0.083  WORSE     NOISE (inside the 0.056 the unchanged runs already spanned)
  pickup_invented            0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  inscription_misquoted      0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  truncated_prose            0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  third_person_protagonist   0.000 -> 0.000  unchanged NOISE (inside the 0.011 the unchanged runs already spanned)
  blow_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  toll_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  throw_contradicted         0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  body_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  beat_contradicted          0.000 -> 0.000  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  refusals                   0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  failures                   0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  omitted_fields             0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  cap_hits                   0 -> 0  unchanged NOISE (inside the 0.000 the unchanged runs already spanned)
  latency_median             1.61s -> 1.49s  BETTER    REAL (p=0.0286)
  latency_p95                2.20s -> 2.09s  BETTER    NOISE (inside the 0.328 the unchanged runs already spanned)
  output_tokens              12693 -> 12784  reported  NOISE (inside the 477.000 the unchanged runs already spanned)
  words                      97 -> 95  reported  REAL (p=0.0286)
  commitments                3.422 -> 3.250  reported  INCONCLUSIVE

A REAL verdict on a CHECK is what means a prompt change worked. Read `commitments`
beside it: a fall in every rate with a fall in that is prose that says less, which is
the one way to improve these numbers without improving the game (Eval::Richness).
Everything INCONCLUSIVE at these sample sizes means: not enough repetitions.
Confirm a REAL verdict with `rake eval:run` before believing it.
------------------------------------------------------------------------------
```
