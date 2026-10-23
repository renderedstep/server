# The classifier of record: the local pointer reader, read as play reads it

The baseline every later classifier change is judged against. It is the small
pointer model play reads every free-typed line through
(`PointerClassifierAgent`), read by the engine's own local composition
(`classifier::read_locally`), so each reading here is the reading a turn makes.

- **Arm:** `pointer:local`, the running sidecar (`bin/pointer-classifier`),
  asked over HTTP with the engine's own request.
- **Weights:** Ettin-68M with a pointer head, trained on the template lines,
  the owner's own lines and both purchased sets (`m68-both`), at fp32 on one
  thread. `pointer.pt` is `pointer-97a189a4c487f2c7`, the name every request
  and receipt carries. The weights are not in this repository.
- **Run:** four repetitions of all 372 lines at corpus `987e6b7fb383ccc2`,
  request identity `v2:189a5ddbb7f67a32`, one call in flight.
- **Code:** server `e559f60` with this change, engine
  `56d153b8931cdc7141a567c8c84113981723e6ea`.
- Readings only: no weights, no model output beyond the answers composed.
  Free: no key, no model call, nothing spent.

## Figures

```
  strict_accuracy      0.861   the whole answer right, over unarguable lines
  accuracy             0.868   323 of 372
  intent_accuracy      0.922
  refusal_agreement    0.937
  closed_set_misses    20
  out_of_set           64
  latency_median       0.17s..0.18s
  latency_p95          0.24s..0.28s
  failures             0
```

The four repetitions are identical, reading for reading: the model is
deterministic. Four are kept anyway, because `rake eval:classifier_compare`
needs four a side for a verdict.

Which reader answered, each repetition: `typed_model` 282 (sure),
`typed_model_unsure` 82 (unsure, played on its own reading),
`typed_model_throw` 8 (a free throw, not read and pointed at `/throw`).

## Against the stored m68-both set

On the 354 lines the earlier bench set shares, this set is right on 311,
against 308. Every reading is the same except:

- the 8 throw lines, which the engine now refuses before asking the model.
  Two of them, "throw the bolt on the door" and "throw the switch", are labelled
  `other` and were read as drops; they are now right. The six real throws were
  wrong before and are still wrong, now as a refusal that names the command;
- `two-names-talk-perrin`, which the talk-about-another relabel made right.

So moving the composition from the Ruby restatement into the engine changed
no reading the model made.

## What not to do with it

Do not tune the 0.15 presence threshold against this corpus: that would fit
the yardstick, not the game.
