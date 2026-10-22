# The talk-about-another pair, after: System One counts only the people spoken to

Same arm, transport, corpus and repetitions as `classifier-about-before-20261022`:
- **Arm:** Jev 1.13 (TypeSafe direct) in front of `mistralai/mistral-medium-3.1`.
- **Run:** four repetitions of all 372 lines at `987e6b7fb383ccc2`, two calls in flight.
- **Request identity:** `v2:189a5ddbb7f67a32`, unchanged. The model call's request did not move, and the System One request is in no digest.
- Every reading is kept.

It was bought at server `e20c17b`, with the engine at renderedstep/engine#66's head `2d3303475494a46a3e0ba267a9aa8500b28c9cae`. Between `2d33034` and `ce6b5931b90a7ccca5831fe3785bb3e8bd43030b`, the commit the server pins, only `parity/` and `vectors/` files changed, so every request is the same.

That engine differs from the before side's only in three System One strings in `data/playthrough/classifier/request.yml`, approved verbatim:
- one sentence added to `also_named`;
- one sentence replaced in `named_more_than_one`;
- both of its criteria.

The rule they state: for talk, count only the people the player is speaking to.

## Verdicts

Against the before side (`rake eval:classifier_compare`, exact rank test, four a side):

```
  strict_accuracy      0.934 -> 0.937  BETTER   NOISE
  accuracy             0.934 -> 0.938  BETTER   NOISE
  intent_accuracy      0.970 -> 0.970  unchanged NOISE
  refusal_agreement    0.950 -> 0.953  BETTER   NOISE
  closed_set_misses    13 -> 12        BETTER   NOISE
  out_of_set           57 -> 57        unchanged NOISE
  latency_median       0.16s -> 0.12s  BETTER   REAL (p=0.0286)
  latency_p95          1.27s -> 1.02s  BETTER   REAL (p=0.0286)
```

**Not a regression.** Every accuracy figure is NOISE. The latency gain is real, because fewer lines escalate: 93 to 95 a repetition, against 99 to 102.

**What it was for works.**
- The six lines that now play are right 24/24: the relabelled `two-names-talk-perrin` and the five `talk-about-another` lines that are not the control.
  - System One composes each of them itself (`typed_model`), with a two-name reading of 0.07 to 0.21.
  - "Rowe, is Perrin telling the truth?" goes from 0/4 to 4/4.
- The five two-listener lines and the control are still refused 4/4. Each still escalates, with a two-name reading of 0.74 to 0.90, and the model call names the second listener.

**One line moved the wrong way: `two-names-examine-three`**, "read the index and the daybook against each other", fell from 4/4 to 0/4.
- Before: System One composed it without escalating (two-name reading 0.43 to 0.48), and named the daybook as `also_named`, so the line was refused.
- Now: the reading is 0.35 to 0.40, and System One names nothing second, so the line plays as an examine of the index.
- It is an examine line, not a talk line, so the new talk sentences reach further than they say. It was the closest call on that side of the threshold before.

Other lines that moved by a reading or two, either way:
- `move-third-stair` 2 -> 3
- `other-impossible` 0 -> 1
- `unresolved-move-window` 3 -> 4
- `two-names-move-office` 2 -> 4
- `unresolved-talk-sealed-room` 2 -> 4
- `real-look-up-annoyed` 4 -> 3
- `real-what-is-on-my-desk` 4 -> 3

## Spend

Booked from provider-reported charges on every settled call (`receipts.json`): **$0.161348** for 376 escalations. No call was unsettled, and the highest single charge was $0.0006064.

The credit reading bracket is $0.151473.

Both sides together, including the aborted start: **$0.372162** against the $0.40 cap. The System One requests are unreceipted.

```sh
rake eval:classifier_compare BEFORE=classifier-about-before-20261022 AFTER=classifier-about-after-20261022
```
