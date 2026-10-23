# The classifier of record: the local pointer reader, read as play reads it

The baseline every later classifier change is judged against. It is the small
pointer model play reads every free-typed line through
(`PointerClassifierAgent`), read by the engine's own local composition
(`classifier::read_locally`), so each reading here is the reading a turn makes.

- **Arm:** `pointer:local`, the running sidecar (`bin/pointer-classifier`),
  asked over HTTP with the engine's own request.
- **Weights:** Ettin-68M with a pointer head, trained by
  `script/pointer_classifier/train.py` exactly as it stands in this repository
  (`m68-step1`), at fp32 on one thread. `pointer.pt` is
  `pointer-032123780e5fb34c`, the name every request and receipt carries. The
  weights are not in this repository.
- **Run:** four repetitions of all 372 lines at corpus `987e6b7fb383ccc2`,
  request identity `v2:189a5ddbb7f67a32`, one call in flight.
- **Code:** server `e510a9e`, engine
  `9d59cb80296dd421fcfea6d882897c773d54f9b1`.
- Readings only: no weights, no model output beyond the answers composed.
  Free: no key, no model call, nothing spent.

## Figures

```
  strict_accuracy      0.861   the whole answer right, over unarguable lines
  accuracy             0.868   323 of 372
  intent_accuracy      0.925
  refusal_agreement    0.931
  closed_set_misses    21
  out_of_set           57
  latency_median       0.11s..0.12s
  latency_p95          0.16s..0.18s
  failures             0
```

The four repetitions are identical, reading for reading: the model is
deterministic. Four are kept anyway, because `rake eval:classifier_compare`
needs four a side for a verdict.

Which reader answered, each repetition: `typed_model` 284 (sure),
`typed_model_unsure` 80 (unsure, played on its own reading),
`typed_model_throw` 8 (a free throw, not read and pointed at `/throw`).

## Against the m68-both set it replaces

`classifier-pointer-m68-both-20261023`, the earlier weights read the same way
at the same corpus and request, is in git history. Against it:
`strict_accuracy` and `accuracy` are unchanged (323 of 372 each side); eleven
lines turned right and eleven turned wrong. `intent_accuracy` and `out_of_set`
moved better and `refusal_agreement` and `closed_set_misses` worse, each by a
line or a few. The two models tie on the whole answer; these weights were
chosen because their recipe is the one in this repository and because they
keep the same score at int8, where m68-both loses lines.

## What not to do with it

Do not tune the 0.15 presence threshold against this corpus: that would fit
the yardstick, not the game.
