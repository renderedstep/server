# The local reader on the dressed worlds, before the ask

The before side of the refuse-and-ask ruling of 2026-10-29: the small pointer
model play reads every free-typed line through (`PointerClassifierAgent`),
read by the engine's own local composition, at today's corpus on the dressed
worlds, as it played before the ruling. A line it was unsure of was played on
its own reading and recorded `typed_model_unsure`. Its after side is
`classifier-pointer-ask-20261029`, whose README has the verdict.

- **Arm:** `pointer:local`, the running sidecar (`bin/pointer-classifier`),
  asked over HTTP with the engine's own request.
- **Weights:** `pointer-032123780e5fb34c` (m68-step1), at fp32 on one
  thread. The weights are not in this repository.
- **Run:** four repetitions of all 437 lines at corpus `5cdba44d04b495a5`,
  request identity `v2:1114445e276715d7`, eight calls in flight.
- **Code:** server `7dad374` (renderedstep/server#363's head), engine
  `88400098a9f3ff9fba086f0cb8a1816bbeff1e05`.
- Every reading is kept. Free: no key, no model call, nothing spent.

## Figures

```
  strict_accuracy      0.749   the whole answer right, over unarguable lines
  accuracy             0.764   334 of 437
  intent_accuracy      0.819
  refusal_agreement    0.839
  closed_set_misses    24
  out_of_set           64
  latency_median       0.15s
  latency_p95          0.21s..0.23s
  failures             0
```

The four repetitions are identical, reading for reading. Which reader
answered, each repetition: `typed_model` 328, `typed_model_unsure` 78 (played
on its own reading), `typed_model_dress` 23, `typed_model_throw` 8.

Against `classifier-pointer-m68-step1-20261023` (323 of 372) this scored more
lines on a moved corpus and on dressed worlds, so the two are not compared.
On the corpus before the dressing the scout of 2026-10-29 measured the same
weights at 336 of 437.
